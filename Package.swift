// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "swift-bundler",
  platforms: [.macOS(.v10_13)],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
    .package(name: "DeltaLogger", url: "https://github.com/stackotter/delta-logger", .branch("main")),
    .package(url: "https://github.com/norio-nomura/SwiftBacktrace", from: "1.0.1"),
  ],
  targets: [
    .target(
      name: "swift-bundler",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        "DeltaLogger",
        "SwiftBacktrace"
      ]),
  ]
)
