// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "Library",
    products: [
        .library(name: "Library", type: .dynamic, targets: ["Library"]),
    ],
    targets: [
        .target(name: "Library"),
        .testTarget(name: "LibraryTests", dependencies: ["Library"]),
    ]
)
