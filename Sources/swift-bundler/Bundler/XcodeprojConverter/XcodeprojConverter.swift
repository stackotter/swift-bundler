import Foundation
import SwiftXcodeProj
import TOMLKit

/// A utility for converting xcodeproj's to Swift Bundler projects.
enum XcodeprojConverter {
  /// Converts an xcodeproj to a Swift Bundler project.
  /// - Parameters:
  ///   - xcodeProjectFile: The xcodeproj to convert.
  ///   - outputDirectory: The Swift Bundler project's directory.
  /// - Returns: A failure if an error occurs.
  static func convert(
    _ xcodeProjectFile: URL,
    outputDirectory: URL
  ) -> Result<Void, XcodeprojConverterError> {
    // Ensure that output directory doesn't already exist
    guard !FileManager.default.fileExists(atPath: outputDirectory.path) else {
      log.error("Directory already exists at '\(outputDirectory.relativePath)'")
      return .failure(.directoryAlreadyExists(outputDirectory))
    }

    // Load xcodeproj
    let project: XcodeProj
    do {
      project = try XcodeProj(pathString: xcodeProjectFile.path)
    } catch {
      return .failure(.failedToLoadXcodeProj(xcodeProjectFile, error))
    }

    let sourceRoot = xcodeProjectFile.deletingLastPathComponent()
    let sourcesDirectory = outputDirectory.appendingPathComponent("Sources")

    // Extract and convert targets
    return extractTargets(from: project).flatMap { targets in
      // Copy targets and then create configuration files
      return copyTargets(
        targets,
        to: sourcesDirectory,
        xcodeprojSourceRoot: sourceRoot
      ).flatMap { _ in
        // Create Package.swift
        return createPackageManifestFile(
          at: outputDirectory.appendingPathComponent("Package.swift"),
          packageName: xcodeProjectFile.deletingPathExtension().lastPathComponent,
          targets: targets
        )
      }.flatMap { _ in
        // Create Bundler.toml
        return createPackageConfigurationFile(
          at: outputDirectory.appendingPathComponent("Bundler.toml"),
          targets: targets
        )
      }
    }
  }

  /// Extracts the targets of an xcodeproj.
  /// - Parameter project: The xcodeproj to extract the targets from.
  /// - Returns: The extracted targets, or a failure if an error occurs.
  static func extractTargets(
    from project: XcodeProj
  ) -> Result<[XcodeTarget], XcodeprojConverterError> {
    var targets: [XcodeTarget] = []
    for target in project.pbxproj.nativeTargets {
      let name = target.name

      guard target.productType == .application else {
        log.warning("Non-executable targets not yet supported. Skipping '\(name)'")
        continue
      }

      log.info("Loading target '\(name)'")

      // Enumerate the target's source files
      let sources: [XcodeFile]
      do {
        sources = try target.sourceFiles().compactMap { file -> XcodeFile? in
          guard
            let path = file.path,
            let sourceTree = file.sourceTree
          else {
            log.warning("Skipping invalid source file '\(file.name ?? "Unknown name")'")
            return nil
          }

          return XcodeFile(path: path, sourceTree: sourceTree, parent: file.parent)
        }
      } catch {
        return .failure(.failedToEnumerateSources(target: name, error))
      }

      // Enumerate the target's resource files
      let resources = try? target.resourcesBuildPhase()?.files?.compactMap { file -> XcodeFile? in
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

      targets.append(XcodeTarget(
        name: name,
        sources: sources,
        resources: resources ?? []
      ))
    }

    return .success(targets)
  }

  /// Copies the given xcodeproj targets into a Swift Bundler project.
  /// - Parameters:
  ///   - targets: The targets to copy.
  ///   - sourcesDirectory: The directory within the Swift Bundler project containing the sources for each target.
  ///   - xcodeprojSourceRoot: The root directory of the xcodeproj.
  /// - Returns: A failure if an error occurs.
  static func copyTargets(
    _ targets: [XcodeTarget],
    to sourcesDirectory: URL,
    xcodeprojSourceRoot: URL
  ) -> Result<Void, XcodeprojConverterError> {
    for target in targets {
      let result = copyTarget(target, to: sourcesDirectory, xcodeprojSourceRoot: xcodeprojSourceRoot)

      if case .failure = result {
        return result
      }
    }

    return .success()
  }

  /// Copies an xcodeproj targets into a Swift Bundler project.
  /// - Parameters:
  ///   - target: The target to copy.
  ///   - sourcesDirectory: The directory within the Swift Bundler project containing the sources for each target.
  ///   - xcodeprojSourceRoot: The root directory of the xcodeproj.
  /// - Returns: A failure if an error occurs.
  static func copyTarget(
    _ target: XcodeTarget,
    to sourcesDirectory: URL,
    xcodeprojSourceRoot: URL
  ) -> Result<Void, XcodeprojConverterError> {
    log.info("Copying files for target '\(target.name)'")

    for file in target.files {
      // Get source and destination
      let result: Result<Void, XcodeprojConverterError> = file.relativePath().flatMap { relativePath in
        let targetDirectory = sourcesDirectory.appendingPathComponent(target.name)
        let source = xcodeprojSourceRoot.appendingPathComponent(relativePath)

        // Simplify destination path
        var relativePath = relativePath
        if relativePath.hasPrefix(target.name) {
          // Files are usually under a folder matching the name of the target. To reduce unnecessary
          // nesting, remove this folder from the destination if present.
          relativePath.removeFirst(target.name.count + 1)
        }

        let destination = targetDirectory.appendingPathComponent(relativePath)

        // Create output directory
        do {
          try FileManager.default.createDirectory(at: targetDirectory)
        } catch {
          return .failure(.failedToCreateTargetDirectory(target: target.name, targetDirectory, error))
        }

        // Copy item
        do {
          // Create parent directory if required
          let directory = destination.deletingLastPathComponent()
          if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory)
          }

          try FileManager.default.copyItem(at: source, to: destination)
        } catch {
          return .failure(.failedToCopyFile(source: source, destination: destination, error))
        }

        return .success()
      }

      if case .failure = result {
        return result
      }
    }

    return .success()
  }

  /// Creates a `Bundler.toml` file declaring the given executable targets as apps.
  /// - Parameters:
  ///   - file: The location to create the file at.
  ///   - targets: The executable targets to add as apps.
  /// - Returns: A failure if an error occurs.
  static func createPackageConfigurationFile(
    at file: URL,
    targets: [XcodeTarget]
  ) -> Result<Void, XcodeprojConverterError> {
    let configuration = createPackageConfiguration(targets: targets)
    do {
      try TOMLEncoder().encode(configuration).write(to: file, atomically: false, encoding: .utf8)
    } catch {
      return .failure(.failedToCreateConfigurationFile(file, error))
    }

    return .success()
  }

  /// Creates a package configuration declaring the given executable targets as apps.
  /// - Parameter targets: The executable targets to add as apps.
  /// - Returns: The configuration.
  static func createPackageConfiguration(targets: [XcodeTarget]) -> PackageConfiguration {
    var apps: [String: AppConfiguration] = [:]
    for target in targets {
      apps[target.name] = AppConfiguration(
        identifier: "com.example.\(target.name)",
        product: target.name,
        version: "0.1.0"
      )
    }

    return PackageConfiguration(apps)
  }

  /// Creates a `Package.swift` file declaring the given targets.
  /// - Parameters:
  ///   - file: The location to create the file at.
  ///   - packageName: The name to give the package.
  ///   - targets: The targets to declare.
  /// - Returns: A failure if an error occurs.
  static func createPackageManifestFile(
    at file: URL,
    packageName: String,
    targets: [XcodeTarget]
  ) -> Result<Void, XcodeprojConverterError> {
    let contents = createPackageManifestContents(
      packageName: packageName,
      targets: targets
    )

    do {
     try contents.write(to: file, atomically: false, encoding: .utf8)
    } catch {
      return .failure(.failedToCreatePackageManifest(file, error))
    }

    return .success()
  }

  /// Creates the contents of a `Package.swift` file declaring the given targets.
  /// - Parameters:
  ///   - packageName: The package's name.
  ///   - targets: The targets to declare.
  /// - Returns: The generated contents.
  static func createPackageManifestContents(packageName: String, targets: [XcodeTarget]) -> String {
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

    let packageManifestContents = """
// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "\(packageName)",
    platforms: [.macOS(.v11), .iOS(.v14)],
    dependencies: [],
    targets: [
\(targetsString)
    ]
)
"""

    return packageManifestContents
  }
}
