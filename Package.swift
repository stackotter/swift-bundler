// swift-tools-version:5.3

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
    .package(url: "https://github.com/LebJe/TOMLKit.git", from: "0.5.0"),
    .package(url: "https://github.com/pointfreeco/swift-parsing.git", from: "0.7.1")
  ],
  targets: [
    .target(
      name: "swift-bundler",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "Logging", package: "swift-log"),
        .product(name: "Parsing", package: "swift-parsing"),
        "TOMLKit"
      ])
  ]
)
