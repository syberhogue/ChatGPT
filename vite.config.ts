import { defineConfig } from 'vite';
import { resolve } from 'path';

export default defineConfig({
  root: 'src/viewer',
  build: {
    outDir: resolve(__dirname, 'dist/viewer'),
    emptyOutDir: true
  },
  server: {
    port: 5173
  }
});
