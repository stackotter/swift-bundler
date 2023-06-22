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
    .package(url: "https://github.com/LebJe/TOMLKit", branch: "main"),
    .package(url: "https://github.com/onevcat/Rainbow", from: "3.0.0"),
    .package(url: "https://github.com/mxcl/Version.git", from: "2.0.0"),
    .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
    .package(url: "https://github.com/stackotter/XcodeGen", exact: "2.35.1"),
    .package(
      url: "https://github.com/apple/swift-syntax", exact: "0.50800.0-SNAPSHOT-2022-12-29-a"),
    .package(
      url: "https://github.com/apple/swift-format", exact: "0.50800.0-SNAPSHOT-2022-12-29-a"),
    .package(url: "https://github.com/pointfreeco/swift-overture", from: "0.5.0"),
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
        .product(name: "XcodeGenKit", package: "XcodeGen"),
        .product(name: "ProjectSpec", package: "XcodeGen"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
        .product(name: "SwiftFormat", package: "swift-format"),
        .product(name: "SwiftFormatConfiguration", package: "swift-format"),
        .product(name: "Overture", package: "swift-overture"),
      ]
    ),

    .executableTarget(
      name: "schema-gen",
      dependencies: [
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftParser", package: "swift-syntax"),
      ]
    ),

    // The target containing documentation
    .target(
      name: "SwiftBundler",
      path: "Documentation",
      exclude: ["preview_docs.sh"]
    ),
  ]
)
