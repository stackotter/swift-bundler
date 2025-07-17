// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "DarwinDynamicDependencies",
    platforms: [.macOS(.v10_13)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.7.1"),
        .package(path: "./Library"),
    ],
    targets: [
        .executableTarget(
            name: "DarwinDynamicDependencies",
            dependencies: ["Sparkle", "Library"]
        ),
    ]
)
