// swift-tools-version:5.6

import PackageDescription

let package = Package(
  name: "swift-bundler",
  platforms: [.macOS(.v11)],
  products: [
    .executable(name: "swift-bundler", targets: ["swift-bundler"]),
    .plugin(name: "SwiftBundlerCommandPlugin", targets: ["SwiftBundlerCommandPlugin"]),
  ],
  dependencies: [
    .package(url: "https://github.com/stackotter/swift-arg-parser", revision: "b1b5373"),
    .package(url: "https://github.com/apple/swift-log", from: "1.5.4"),
    .package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.7.1"),
    .package(url: "https://github.com/furby-tm/TOMLKit", from: "0.5.6"),
    .package(url: "https://github.com/onevcat/Rainbow", from: "3.0.0"),
    .package(url: "https://github.com/mxcl/Version.git", from: "2.0.0"),
    .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
    .package(url: "https://github.com/stackotter/XcodeGen", exact: "2.35.1"),
    .package(
      url: "https://github.com/apple/swift-syntax", exact: "510.0.1"
    ),
    .package(
      url: "https://github.com/apple/swift-format", exact: "510.0.1"
    ),
    .package(url: "https://github.com/pointfreeco/swift-overture", from: "0.5.0"),
  ],
  targets: [
    .executableTarget(
      name: "swift-bundler",
      dependencies: [
        .product(name: "StackOtterArgParser", package: "swift-arg-parser"),
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

    .plugin(
      name: "SwiftBundlerCommandPlugin",
      capability: .command(
        intent: .custom(
          verb: "bundler",
          description: "Run a package as an app."
        ),
        permissions: [
          .writeToPackageDirectory(
            reason: "Creating an app bundle requires writing to the package directory.")
        ]
      ),
      dependencies: [
        .target(name: "swift-bundler")
      ]
    ),
  ]
)
