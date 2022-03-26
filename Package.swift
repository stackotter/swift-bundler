// swift-tools-version:5.5

import PackageDescription

let package = Package(
  name: "swift-bundler",
  platforms: [.macOS(.v10_15)],
  products: [
    .executable(name: "swift-bundler", targets: ["swift-bundler"])
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-log", from: "1.4.2"),
    .package(url: "https://github.com/pointfreeco/swift-parsing.git", from: "0.7.1"),
    .package(url: "https://github.com/LebJe/TOMLKit", from: "0.5.0")
  ],
  targets: [
    .executableTarget(
      name: "swift-bundler",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "Logging", package: "swift-log"),
        .product(name: "Parsing", package: "swift-parsing"),
        .product(name: "TOMLKit", package: "TOMLKit")
      ])
  ]
)
