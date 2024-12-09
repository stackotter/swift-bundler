// swift-tools-version:5.7

import PackageDescription

let package = Package(
  name: "swift-bundler",
  platforms: [.macOS(.v10_15)],
  products: [
    .executable(name: "swift-bundler", targets: ["swift-bundler"]),
    .library(name: "SwiftBundlerRuntime", targets: ["SwiftBundlerRuntime"]),
    .plugin(name: "SwiftBundlerCommandPlugin", targets: ["SwiftBundlerCommandPlugin"]),
  ],
  dependencies: [
    .package(url: "https://github.com/stackotter/swift-arg-parser", revision: "b1b5373"),
    .package(url: "https://github.com/apple/swift-log", from: "1.5.4"),
    .package(url: "https://github.com/pointfreeco/swift-parsing", "0.11.0"..<"0.12.0"),
    .package(url: "https://github.com/stackotter/TOMLKit", from: "0.6.1"),
    .package(url: "https://github.com/onevcat/Rainbow", from: "3.0.0"),
    .package(url: "https://github.com/mxcl/Version.git", from: "2.0.0"),
    .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
    .package(url: "https://github.com/tuist/XcodeProj.git", .upToNextMajor(from: "8.25.0")),
    .package(url: "https://github.com/apple/swift-syntax", exact: "510.0.1"),
    .package(url: "https://github.com/apple/swift-format", exact: "510.0.1"),
    .package(url: "https://github.com/pointfreeco/swift-overture", from: "0.5.0"),
    .package(url: "https://github.com/stackotter/Socket", from: "0.3.3"),
    .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.2"),

    // File watcher dependencies
    .package(url: "https://github.com/sersoft-gmbh/swift-inotify", "0.4.0"..<"0.5.0"),
    .package(url: "https://github.com/apple/swift-system.git", from: "1.2.0"),
    .package(url: "https://github.com/apple/swift-async-algorithms.git", from: "0.1.0"),
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
        "Socket",
        "HotReloadingProtocol",
        "FileSystemWatcher",
        "Yams",
        "XcodeProj",
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

    .target(
      name: "SwiftBundlerRuntime",
      dependencies: [
        "Socket",
        "HotReloadingProtocol",
      ]
    ),

    .target(
      name: "HotReloadingProtocol",
      dependencies: [
        "Socket"
      ]
    ),

    .target(
      name: "FileSystemWatcher",
      dependencies: [
        .product(
          name: "Inotify",
          package: "swift-inotify",
          condition: .when(platforms: [.linux])
        ),
        .product(
          name: "SystemPackage",
          package: "swift-system",
          condition: .when(platforms: [.linux])
        ),
        .product(
          name: "AsyncAlgorithms",
          package: "swift-async-algorithms",
          condition: .when(platforms: [.linux])
        ),
      ]
    ),

    .testTarget(
      name: "SwiftBundlerTests",
      dependencies: ["swift-bundler"]
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
