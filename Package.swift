// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VideoConverter",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "VideoConverterApp", targets: ["VideoConverterApp"]),
        .executable(name: "VideoConverterCLI", targets: ["VideoConverterCLI"]),
        .library(name: "VideoConverterCore", targets: ["VideoConverterCore"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "VideoConverterCore",
            path: "Sources/VideoConverterCore"
        ),
        .executableTarget(
            name: "VideoConverterApp",
            dependencies: ["VideoConverterCore"],
            path: "Sources/VideoConverterApp",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .define("APP_TARGET")
            ]
        ),
        .executableTarget(
            name: "VideoConverterCLI",
            dependencies: ["VideoConverterCore"],
            path: "Sources/VideoConverterCLI"
        )
    ]
)
