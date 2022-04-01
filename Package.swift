// swift-tools-version:5.5

import PackageDescription

var dependencies: [Package.Dependency] = [
  .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
  .package(url: "https://github.com/apple/swift-log", from: "1.4.2"),
  .package(url: "https://github.com/pointfreeco/swift-parsing.git", from: "0.7.1"),
  .package(url: "https://github.com/LebJe/TOMLKit", from: "0.5.1"),
  .package(url: "https://github.com/onevcat/Rainbow", .upToNextMajor(from: "4.0.0")),
  .package(url: "https://github.com/mxcl/Version.git", from: "2.0.0")
]

#if swift(>=5.6)
// Add the documentation compiler plugin if possible
dependencies.append(
    .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0")
)
#endif

let package = Package(
  name: "swift-bundler",
  platforms: [.macOS(.v10_15)],
  products: [
    .executable(name: "swift-bundler", targets: ["swift-bundler"])
  ],
  dependencies: dependencies,
  targets: [
    .executableTarget(
      name: "swift-bundler",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "Logging", package: "swift-log"),
        .product(name: "Parsing", package: "swift-parsing"),
        "TOMLKit",
        "Rainbow",
        "Version"
      ])
  ]
)
