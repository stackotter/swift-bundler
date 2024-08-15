// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "BuildTools",
  platforms: [.macOS(.v10_11)],
  dependencies: [
    .package(url: "https://github.com/cpisciotta/xcbeautify", from: "2.11.0"),
  ],
  targets: [
    .target(name: "BuildTools", path: "")
  ]
)
