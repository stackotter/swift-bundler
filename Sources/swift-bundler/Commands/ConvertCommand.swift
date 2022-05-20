import Foundation
import ArgumentParser
import TOMLKit
import SwiftXcodeProj

/// The command for converting xcodeprojs to Swift Bundler projects.
struct ConvertCommand: Command {
  static var configuration = CommandConfiguration(
    commandName: "convert",
    abstract: "Converts an xcodeproj to a Swift Bundler project."
  )

  @Argument(
    help: "Xcodeproj to convert.",
    transform: URL.init(fileURLWithPath:))
  var xcodeProjectFile: URL

  @Option(
    name: [.customShort("o"), .customLong("out")],
    help: "The output directory.",
    transform: URL.init(fileURLWithPath:))
  var outputDirectory: URL

  func wrappedRun() throws {
    // Convert executable targets
    // Convert library dependency targets
    // Check deployment platforms
    // Copy indentation settings
    // Preserve project structure
    log.warning("Converting xcodeprojs is currently an experimental feature. Proceed with caution.")
    print("[press ENTER to continue]", terminator: "")
    _ = readLine()

    guard !FileManager.default.fileExists(atPath: outputDirectory.path) else {
      log.error("Directory already exists at '\(outputDirectory.relativePath)'")
      Foundation.exit(1)
    }

    let project = try XcodeProj(pathString: xcodeProjectFile.path)
    let sourceRoot = xcodeProjectFile.deletingLastPathComponent().path

    struct Target {
      var name: String
      var resourcePaths: [String]
    }

    var targets: [Target] = []

    let sourcesDirectory = outputDirectory.appendingPathComponent("Sources")
    for target in project.pbxproj.nativeTargets {
      let name = target.name

      guard target.productType == .application else {
        log.warning("Non-executable targets not yet supported. Skipping '\(name)'.")
        continue
      }

      log.info("Converting target '\(name)'")

      // Enumerate the target's files
      var filesToCopy: [String] = []

      let sourceFiles = try target.sourceFiles().compactMap { file in
        return try file.fullPath(sourceRoot: sourceRoot)
      }

      filesToCopy += sourceFiles

      var resourcePaths: [String] = []
      if let resourceFiles = try? target.resourcesBuildPhase()?.files {
        let fullPaths = try resourceFiles.compactMap { file in
          return try file.file?.fullPath(sourceRoot: sourceRoot)
        }

        filesToCopy += fullPaths
        resourcePaths = resourceFiles.compactMap(\.file?.path)
      }

      // Create output directory
      let targetDirectory = sourcesDirectory.appendingPathComponent(name)
      try FileManager.default.createDirectory(at: targetDirectory)

      // Copy target's files to output directory
      for file in filesToCopy.map(URL.init(fileURLWithPath:)) {
        try FileManager.default.copyItem(at: file, to: targetDirectory.appendingPathComponent(file.lastPathComponent))
      }

      targets.append(Target(name: name, resourcePaths: resourcePaths))
    }

    let targetsString = targets.map { target in
      let resourcesString = target.resourcePaths.map { path in
        return "                .process(\"\(path)\")"
      }.joined(separator: ",\n")
      return """
        .executableTarget(
            name: "\(target.name)",
            dependencies: [],
            resources: [
                \(resourcesString)
            ]
        )
"""
    }.joined(separator: ",\n")

    let packageManifest = """
// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "\(xcodeProjectFile.deletingPathExtension().lastPathComponent)",
    platforms: [.macOS(.v11), .iOS(.v14)],
    dependencies: [],
    targets: [
        \(targetsString)
    ]
)
"""

    try packageManifest.write(to: outputDirectory.appendingPathComponent("Package.swift"), atomically: false, encoding: .utf8)

    var apps: [String: AppConfiguration] = [:]
    for target in targets {
      apps[target.name] = AppConfiguration(
        identifier: "com.example.\(target.name)",
        product: target.name,
        version: "0.1.0"
      )
    }

    let configuration = PackageConfiguration(apps)
    try TOMLEncoder().encode(configuration).write(to: outputDirectory.appendingPathComponent("Bundler.toml"), atomically: false, encoding: .utf8)
  }
}
