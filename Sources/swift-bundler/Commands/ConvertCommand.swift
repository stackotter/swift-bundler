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
    let sourceRoot = xcodeProjectFile.deletingLastPathComponent()
    
    struct XcodeFile {
      var path: String
      var sourceTree: PBXSourceTree
      var parent: PBXFileElement?

      func absolutePath(sourceRoot: URL) throws -> URL {
        switch sourceTree {
          case .absolute:
            return URL(fileURLWithPath: path)
          default:
            return sourceRoot.appendingPathComponent(try relativePath())
        }
      }

      func relativePath() throws -> String {
        switch sourceTree {
          case .absolute:
            return URL(fileURLWithPath: path).lastPathComponent
          case .sourceRoot:
            return path
          case .group:
            guard let parent = parent, let sourceTree = parent.sourceTree else {
              return path
            }

            let parentGroup = XcodeFile(
              path: parent.path ?? "",
              sourceTree: sourceTree,
              parent: parent.parent
            )

            let parentPath = try parentGroup.relativePath()
            if path != "" && parentPath != "" {
              return parentPath + "/" + path
            } else if parentPath != "" {
              return parentPath
            } else {
              return path
            }
          default:
            fatalError("Unsupported path type: \(sourceTree)")
        }
      }
    }

    struct Target {
      var name: String
      var resources: [XcodeFile]
    }

    var targets: [Target] = []

    let sourcesDirectory = outputDirectory.appendingPathComponent("Sources")
    for target in project.pbxproj.nativeTargets {
      let name = target.name

      guard target.productType == .application else {
        log.warning("Non-executable targets not yet supported. Skipping '\(name)'")
        continue
      }

      log.info("Converting target '\(name)'")

      // Enumerate the target's files
      var filesToCopy: [XcodeFile] = []

      let sourceFiles = try target.sourceFiles().compactMap { file -> XcodeFile? in
        guard 
          let path = file.path,
          let sourceTree = file.sourceTree
        else {
          log.warning("Skipping invalid source file '\(file.name ?? "Unknown name")'")
          return nil
        }

        return XcodeFile(path: path, sourceTree: sourceTree, parent: file.parent)
      }

      filesToCopy += sourceFiles

      var resources: [XcodeFile] = []
      if let resourceFiles = try? target.resourcesBuildPhase()?.files {
        let files = resourceFiles.compactMap { file -> XcodeFile? in
          guard
            let file = file.file,
            let path = file.path,
            let sourceTree = file.sourceTree
          else {
            log.warning("Skipping invalid resource file '\(file.file?.name ?? "Unknown name")'")
            return nil
          }

          return XcodeFile(path: path, sourceTree: sourceTree, parent: file.parent)
        }

        filesToCopy += files
        resources = files
      }

      // Create output directory
      let targetDirectory = sourcesDirectory.appendingPathComponent(name)
      try FileManager.default.createDirectory(at: targetDirectory)

      // Copy target's files to output directory
      for file in filesToCopy {
        // Get source and destination
        let absolutePath = try file.absolutePath(sourceRoot: sourceRoot)
        var relativePath = try file.relativePath()
        if relativePath.hasPrefix(name) {
          // Remove the redundant initial folder and the following '/'
          relativePath.removeFirst(name.count + 1)
        }
        
        let destination = targetDirectory.appendingPathComponent(relativePath)

        // Create parent directory if required
        let directory = destination.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
          try FileManager.default.createDirectory(at: directory)
        }

        try FileManager.default.copyItem(at: absolutePath, to: destination)
      }

      targets.append(Target(name: name, resources: resources))
    }

    let targetsString = targets.map { target in
      let resourcesString = target.resources.map { file in
        return "                .process(\"\(file.path)\")"
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
