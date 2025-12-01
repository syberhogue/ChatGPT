import {
  AmbientLight,
  Box3,
  BufferAttribute,
  BufferGeometry,
  Color,
  DirectionalLight,
  GridHelper,
  Group,
  Mesh,
  MeshStandardMaterial,
  SRGBColorSpace,
  Object3D,
  PerspectiveCamera,
  Scene,
  Vector3,
  WebGLRenderer
} from 'three';
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js';
import { OBJLoader } from 'three/examples/jsm/loaders/OBJLoader.js';
import { STLLoader } from 'three/examples/jsm/loaders/STLLoader.js';

type SupportedExt = 'obj' | 'stl';

type SupportedFile = File & { name: string };

class ModelViewer {
  private readonly container: HTMLElement;
  private readonly renderer: WebGLRenderer;
  private readonly scene: Scene;
  private readonly camera: PerspectiveCamera;
  private readonly controls: OrbitControls;
  private readonly objLoader = new OBJLoader();
  private readonly stlLoader = new STLLoader();
  private readonly infoModel: HTMLElement;
  private readonly infoFaces: HTMLElement;
  private readonly toggleButton: HTMLButtonElement;
  private readonly fileInput: HTMLInputElement;

  private modelName = 'None';
  private faceCount = 0;
  private wireframe = false;
  private activeGroup?: Group;

  constructor(container: HTMLElement) {
    this.container = container;
    this.container.style.position = 'relative';

    const { width, height } = this.getContainerSize();
    this.renderer = new WebGLRenderer({ antialias: true });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    this.renderer.setSize(width, height);
    this.renderer.outputColorSpace = SRGBColorSpace;
    this.container.appendChild(this.renderer.domElement);

    this.scene = new Scene();
    this.scene.background = new Color('#0d1117');

    this.camera = new PerspectiveCamera(60, width / height, 0.01, 100);
    this.camera.position.set(2.5, 2.5, 2.5);

    this.controls = new OrbitControls(this.camera, this.renderer.domElement);
    this.controls.enableDamping = true;
    this.controls.target.set(0, 0.25, 0);

    this.addLights();
    this.addGrid();
    this.buildUi();
    this.animate();

    window.addEventListener('resize', () => this.handleResize());
  }

  public async loadFile(file: SupportedFile): Promise<void> {
    const extension = this.getExtension(file.name);
    if (!extension) {
      throw new Error('Unsupported file type. Please provide OBJ or STL.');
    }

    let object: Object3D;
    if (extension === 'obj') {
      const text = await file.text();
      object = this.objLoader.parse(text);
    } else {
      const buffer = await file.arrayBuffer();
      const geometry = this.stlLoader.parse(buffer);
      object = new Mesh(geometry);
    }

    this.displayObject(object, file.name);
  }

  public async loadFromUrl(url: string, displayName?: string): Promise<void> {
    const extension = this.getExtension(url);
    if (!extension) {
      throw new Error('Unsupported file type. Please provide OBJ or STL.');
    }

    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Failed to fetch model: ${response.status} ${response.statusText}`);
    }

    if (extension === 'obj') {
      const text = await response.text();
      this.displayObject(this.objLoader.parse(text), displayName ?? url);
    } else {
      const buffer = await response.arrayBuffer();
      const geometry = this.stlLoader.parse(buffer);
      this.displayObject(new Mesh(geometry), displayName ?? url);
    }
  }

  private displayObject(object: Object3D, name: string): void {
    const { group, faceCount } = this.normalizeAndDecorate(object);
    if (this.activeGroup) {
      this.scene.remove(this.activeGroup);
    }

    this.activeGroup = group;
    this.scene.add(group);
    this.modelName = name;
    this.faceCount = faceCount;
    this.updateInfo();
    this.updateWireframe();
  }

  private normalizeAndDecorate(object: Object3D): { group: Group; faceCount: number } {
    const meshes: Mesh[] = [];

    object.updateWorldMatrix(true, true);
    object.traverse((child) => {
      if ((child as Mesh).isMesh) {
        const mesh = child as Mesh;
        const geometry = mesh.geometry.clone();
        geometry.applyMatrix4(mesh.matrixWorld);
        meshes.push(new Mesh(geometry));
      }
    });

    if (!meshes.length && (object as Mesh).isMesh) {
      const mesh = object as Mesh;
      const geometry = mesh.geometry.clone();
      geometry.applyMatrix4(mesh.matrixWorld);
      meshes.push(new Mesh(geometry));
    }

    if (!meshes.length) {
      throw new Error('No mesh data found in model.');
    }

    const bounds = new Box3();
    meshes.forEach((mesh) => bounds.expandByObject(mesh));

    const size = bounds.getSize(new Vector3());
    const center = bounds.getCenter(new Vector3());
    const maxDimension = Math.max(size.x, size.y, size.z) || 1;
    const scale = 1 / maxDimension;

    const group = new Group();
    let totalFaces = 0;

    meshes.forEach((mesh) => {
      const prepared = this.prepareMesh(mesh, center, scale);
      totalFaces += prepared.faceCount;
      group.add(prepared.mesh);
    });

    return { group, faceCount: totalFaces };
  }

  private prepareMesh(mesh: Mesh, center: Vector3, scale: number): { mesh: Mesh; faceCount: number } {
    const geometry = mesh.geometry.clone();
    geometry.translate(-center.x, -center.y, -center.z);
    geometry.scale(scale, scale, scale);

    const decorated = this.decorateGeometry(geometry);
    decorated.computeVertexNormals();

    const material = new MeshStandardMaterial({
      color: 0xcad3dd,
      metalness: 0.15,
      roughness: 0.75,
      wireframe: this.wireframe
    });

    const preparedMesh = new Mesh(decorated, material);
    preparedMesh.castShadow = true;
    preparedMesh.receiveShadow = true;

    const faceCount = this.countFaces(decorated);
    return { mesh: preparedMesh, faceCount };
  }

  private decorateGeometry(geometry: BufferGeometry): BufferGeometry {
    const working = geometry.index ? geometry.toNonIndexed() : geometry.clone();
    const position = working.getAttribute('position');
    const faceTotal = Math.floor(position.count / 3);

    const faceIds = new Uint32Array(position.count);
    for (let face = 0; face < faceTotal; face += 1) {
      const offset = face * 3;
      faceIds[offset] = face;
      faceIds[offset + 1] = face;
      faceIds[offset + 2] = face;
    }

    working.setAttribute('faceId', new BufferAttribute(faceIds, 1));
    return working;
  }

  private countFaces(geometry: BufferGeometry): number {
    const position = geometry.getAttribute('position');
    return Math.floor(position.count / 3);
  }

  private getExtension(name: string): SupportedExt | null {
    const match = /\.([^.]+)$/i.exec(name);
    const ext = match?.[1].toLowerCase();
    return ext === 'obj' || ext === 'stl' ? ext : null;
  }

  private updateInfo(): void {
    this.infoModel.textContent = `Model: ${this.modelName}`;
    this.infoFaces.textContent = `Faces: ${this.faceCount.toLocaleString()}`;
  }

  private updateWireframe(): void {
    if (!this.activeGroup) return;

    this.activeGroup.traverse((node) => {
      if ((node as Mesh).isMesh) {
        const mesh = node as Mesh;
        if (Array.isArray(mesh.material)) {
          mesh.material.forEach((material) => {
            (material as MeshStandardMaterial).wireframe = this.wireframe;
          });
        } else {
          (mesh.material as MeshStandardMaterial).wireframe = this.wireframe;
        }
      }
    });
    this.toggleButton.textContent = this.wireframe ? 'Show Solid' : 'Show Wireframe';
  }

  private addLights(): void {
    const ambient = new AmbientLight(0xffffff, 0.7);
    const directional = new DirectionalLight(0xffffff, 0.8);
    directional.position.set(5, 10, 7.5);
    directional.castShadow = true;

    this.scene.add(ambient);
    this.scene.add(directional);
  }

  private addGrid(): void {
    const grid = new GridHelper(4, 40, 0x2f353d, 0x1f2329);
    this.scene.add(grid);
  }

  private buildUi(): void {
    const panel = document.createElement('div');
    panel.style.position = 'absolute';
    panel.style.top = '12px';
    panel.style.left = '12px';
    panel.style.padding = '12px';
    panel.style.background = 'rgba(12, 16, 24, 0.8)';
    panel.style.border = '1px solid #30363d';
    panel.style.borderRadius = '10px';
    panel.style.backdropFilter = 'blur(6px)';
    panel.style.boxShadow = '0 8px 24px rgba(0, 0, 0, 0.25)';
    panel.style.display = 'flex';
    panel.style.flexDirection = 'column';
    panel.style.gap = '8px';
    panel.style.color = '#e6edf3';
    panel.style.fontSize = '14px';

    this.infoModel = document.createElement('div');
    this.infoFaces = document.createElement('div');
    this.infoModel.textContent = 'Model: None';
    this.infoFaces.textContent = 'Faces: 0';

    this.toggleButton = document.createElement('button');
    this.toggleButton.textContent = 'Show Wireframe';
    this.toggleButton.style.padding = '8px 10px';
    this.toggleButton.style.borderRadius = '8px';
    this.toggleButton.style.border = '1px solid #30363d';
    this.toggleButton.style.background = '#1f6feb';
    this.toggleButton.style.color = '#f0f6fc';
    this.toggleButton.style.cursor = 'pointer';
    this.toggleButton.style.fontWeight = '600';
    this.toggleButton.addEventListener('click', () => {
      this.wireframe = !this.wireframe;
      this.updateWireframe();
    });

    const fileLabel = document.createElement('label');
    fileLabel.textContent = 'Load OBJ/STL';
    fileLabel.style.display = 'inline-flex';
    fileLabel.style.flexDirection = 'column';
    fileLabel.style.gap = '6px';
    fileLabel.style.fontWeight = '600';
    fileLabel.style.color = '#e6edf3';

    this.fileInput = document.createElement('input');
    this.fileInput.type = 'file';
    this.fileInput.accept = '.obj,.stl';
    this.fileInput.style.padding = '6px 0';
    this.fileInput.addEventListener('change', async () => {
      const file = this.fileInput.files?.[0];
      if (file) {
        await this.loadFile(file as SupportedFile);
      }
    });

    fileLabel.appendChild(this.fileInput);
    panel.appendChild(this.infoModel);
    panel.appendChild(this.infoFaces);
    panel.appendChild(this.toggleButton);
    panel.appendChild(fileLabel);

    this.container.appendChild(panel);
  }

  private handleResize(): void {
    const { width, height } = this.getContainerSize();
    this.camera.aspect = width / height;
    this.camera.updateProjectionMatrix();
    this.renderer.setSize(width, height);
  }

  private getContainerSize(): { width: number; height: number } {
    return {
      width: this.container.clientWidth || window.innerWidth,
      height: this.container.clientHeight || window.innerHeight
    };
  }

  private animate(): void {
    requestAnimationFrame(() => this.animate());
    this.controls.update();
    this.renderer.render(this.scene, this.camera);
  }
}

function bootstrap(): void {
  const host = document.getElementById('viewer-root');
  if (!host) {
    throw new Error('Missing #viewer-root container');
  }

  new ModelViewer(host);
}

document.addEventListener('DOMContentLoaded', bootstrap);
