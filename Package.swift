// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FreeFlow",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "FreeFlowCore",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "FreeFlowCoreTests",
            dependencies: ["FreeFlowCore"],
            path: "Tests/FreeFlowCoreTests"
        )
    ]
)
