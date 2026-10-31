// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Avora",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Avora", targets: ["Avora"]),
        .library(name: "ZoomEngine", targets: ["ZoomEngine"]),
    ],
    targets: [
        .target(name: "ZoomEngine"),
        .executableTarget(
            name: "Avora",
            dependencies: ["ZoomEngine"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(name: "ZoomEngineTests", dependencies: ["ZoomEngine"]),
        .testTarget(
            name: "AvoraTests",
            dependencies: ["Avora"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
