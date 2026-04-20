// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FreeFlowCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "FreeFlowCore", targets: ["FreeFlowCore"])
    ],
    targets: [
        .target(
            name: "FreeFlowCore",
            path: "Sources",
            exclude: ["App.swift"]
        ),
        .testTarget(
            name: "FreeFlowCoreTests",
            dependencies: ["FreeFlowCore"],
            path: "Tests/FreeFlowCoreTests"
        )
    ]
)
