// swift-tools-version:5.7

import PackageDescription

let package = Package(
  name: "swift-bundler",
  platforms: [.macOS(.v10_15)],
  products: [
    .executable(name: "swift-bundler", targets: ["swift-bundler"]),
    .library(name: "SwiftBundler", targets: ["SwiftBundler"]),
    .library(name: "SwiftBundlerRuntime", targets: ["SwiftBundlerRuntime"]),
    .library(name: "SwiftBundlerBuilders", targets: ["SwiftBundlerBuilders"]),
    .plugin(name: "SwiftBundlerCommandPlugin", targets: ["SwiftBundlerCommandPlugin"]),
  ],
  dependencies: [
    .package(url: "https://github.com/stackotter/swift-arg-parser", revision: "b1b5373"),
    .package(url: "https://github.com/apple/swift-log", from: "1.5.4"),
    .package(url: "https://github.com/pointfreeco/swift-parsing", .upToNextMinor(from: "0.13.0")),
    .package(url: "https://github.com/stackotter/TOMLKit", from: "0.6.1"),
    .package(url: "https://github.com/onevcat/Rainbow", from: "4.0.0"),
    .package(url: "https://github.com/mxcl/Version", from: "2.0.0"),
    .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.0.0"),
    .package(url: "https://github.com/tuist/XcodeProj", from: "8.16.0"),
    .package(url: "https://github.com/yonaskolb/XcodeGen", from: "2.42.0"),
    .package(url: "https://github.com/swiftlang/swift-syntax", from: "600.0.0"),
    .package(url: "https://github.com/pointfreeco/swift-overture", from: "0.5.0"),
    .package(url: "https://github.com/stackotter/Socket", from: "0.3.3"),
    .package(url: "https://github.com/jpsim/Yams", from: "5.1.2"),
    .package(url: "https://github.com/kylef/PathKit", from: "1.0.1"),
    .package(url: "https://github.com/apple/swift-certificates", from: "1.7.0"),
    .package(url: "https://github.com/apple/swift-asn1", from: "1.1.0"),
    .package(url: "https://github.com/apple/swift-crypto", from: "3.10.0"),
    .package(url: "https://github.com/CoreOffice/XMLCoder", from: "0.17.1"),

    // File watcher dependencies
    .package(url: "https://github.com/sersoft-gmbh/swift-inotify", "0.4.0"..<"0.5.0"),
    .package(url: "https://github.com/apple/swift-system", from: "1.2.0"),
    .package(url: "https://github.com/apple/swift-async-algorithms", from: "0.1.0"),
  ],
  targets: [
    .executableTarget(name: "swift-bundler", dependencies: ["SwiftBundler"]),
    .target(
      name: "SwiftBundler",
      dependencies: [
        "TOMLKit",
        "Rainbow",
        "Version",
        "Yams",
        "SwiftBundlerBuilders",
        "XMLCoder",
        .product(name: "Crypto", package: "swift-crypto"),
        .product(name: "SwiftASN1", package: "swift-asn1"),
        .product(name: "X509", package: "swift-certificates"),
        .product(name: "StackOtterArgParser", package: "swift-arg-parser"),
        .product(name: "Logging", package: "swift-log"),
        .product(name: "Parsing", package: "swift-parsing"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
        .product(name: "Overture", package: "swift-overture"),

        // Xcodeproj related dependencies
        .product(
          name: "XcodeProj",
          package: "XcodeProj",
          condition: .when(platforms: [.macOS])
        ),
        .product(
          name: "PathKit",
          package: "PathKit",
          condition: .when(platforms: [.macOS])
        ),
        .product(
          name: "XcodeGenKit",
          package: "XcodeGen",
          condition: .when(platforms: [.macOS])
        ),
        .product(
          name: "ProjectSpec",
          package: "XcodeGen",
          condition: .when(platforms: [.macOS])
        ),

        // Hot reloading related dependencies
        .product(
          name: "Socket",
          package: "Socket",
          condition: .when(platforms: [.macOS, .linux])
        ),
        .target(
          name: "HotReloadingProtocol",
          condition: .when(platforms: [.macOS, .linux])
        ),
        .target(
          name: "FileSystemWatcher",
          condition: .when(platforms: [.macOS, .linux])
        ),
      ],
      swiftSettings: [
        .define("SUPPORT_HOT_RELOADING", .when(platforms: [.macOS, .linux])),
        .define("SUPPORT_XCODEPROJ", .when(platforms: [.macOS])),
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
      name: "SwiftBundlerBuilders",
      dependencies: []
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
      name: "SwiftBundlerDocumentation",
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
