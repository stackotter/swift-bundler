// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "ManifestParsingBug",
    platforms: [.macOS(.v10_15)],
    targets: [
        .executableTarget(
            name: "ManifestParsingBug",
            exclude: ["NonExistentImage.png"]
        ),
    ]
)
