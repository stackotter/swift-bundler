// swift-tools-version:5.6

import PackageDescription

let package = Package(
  name: "swift-bundler",
  dependencies: [
    .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0")
  ],
  targets: [
    // The target containing documentation
    .target(
      name: "SwiftBundler",
      path: "SwiftBundler")
  ]
)
