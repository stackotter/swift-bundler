// swift-tools-version:5.6

import PackageDescription

let package = Package(
  name: "swift-bundler",
  platforms: [.macOS(.v11)],
  products: [
    .executable(name: "swift-bundler", targets: ["swift-bundler"])
  ],
  dependencies: [
    .package(url: "https://github.com/stackotter/swift-argument-parser", branch: "main"),
    .package(url: "https://github.com/apple/swift-log", from: "1.4.2"),
    .package(url: "https://github.com/pointfreeco/swift-parsing.git", from: "0.7.1"),
    .package(url: "https://github.com/LebJe/TOMLKit", from: "0.5.2"),
    .package(url: "https://github.com/onevcat/Rainbow", from: "3.0.0"),
    .package(url: "https://github.com/mxcl/Version.git", from: "2.0.0"),
    .package(url: "https://github.com/apple/swift-package-manager", branch: "release/5.6"),
    .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
    .package(url: "https://github.com/stackotter/XcodeGen", branch: "renamed")
  ],
  targets: [
    .executableTarget(
      name: "swift-bundler",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "Logging", package: "swift-log"),
        .product(name: "Parsing", package: "swift-parsing"),
        "TOMLKit",
        "Rainbow",
        "Version",
        .product(name: "SwiftPMDataModel", package: "swift-package-manager"),
        .product(name: "XcodeGenKit", package: "XcodeGen"),
        .product(name: "ProjectSpec", package: "XcodeGen")
      ]
    ),

    // The target containing documentation
    .target(
      name: "SwiftBundler",
      path: "Documentation",
      exclude: ["preview_docs.sh"]
    )
  ]
)
