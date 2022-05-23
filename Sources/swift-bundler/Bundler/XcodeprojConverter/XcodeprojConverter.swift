import Foundation
import SwiftXcodeProj
import TOMLKit
import Version

/// A utility for converting xcodeproj's to Swift Bundler projects.
enum XcodeprojConverter {
  static func convertWorkspace(
    _ xcodeWorkspaceFile: URL,
    outputDirectory: URL
  ) -> Result<Void, XcodeprojConverterError> {
    // Ensure that output directory doesn't already exist
    guard !FileManager.default.fileExists(atPath: outputDirectory.path) else {
      return .failure(.directoryAlreadyExists(outputDirectory))
    }

    // Load xcworkspace
    let workspace: XCWorkspace
    do {
      workspace = try XCWorkspace(pathString: xcodeWorkspaceFile.path)
    } catch {
      return .failure(.failedToLoadXcodeWorkspace(xcodeWorkspaceFile, error))
    }

    // Enumerate projects
    let projects = workspace.data.children.map(\.location.path).map(URL.init(fileURLWithPath:))
    let total = projects.count

    log.info("Converting \(total) projects")

    var successCount = 0
    for (index, project) in projects.enumerated() {
      let projectName = project.deletingPathExtension().lastPathComponent

      log.info("Converting '\(projectName)' (\(index)/\(total))")

      let result = convertProject(
        project,
        outputDirectory: outputDirectory.appendingPathComponent(projectName)
      )

      if case let .failure(error) = result {
        log.error("Failed to convert '\(projectName)': \(error.localizedDescription)")
        continue
      }

      successCount += 1
    }

    log.info("Successfully converted \(successCount)/\(total)")

    return .success()
  }

  /// Converts an xcodeproj to a Swift Bundler project.
  /// - Parameters:
  ///   - xcodeProjectFile: The xcodeproj to convert.
  ///   - outputDirectory: The Swift Bundler project's directory.
  /// - Returns: A failure if an error occurs.
  static func convertProject(
    _ xcodeProjectFile: URL,
    outputDirectory: URL
  ) -> Result<Void, XcodeprojConverterError> {
    // Ensure that output directory doesn't already exist
    guard !FileManager.default.fileExists(atPath: outputDirectory.path) else {
      return .failure(.directoryAlreadyExists(outputDirectory))
    }

    // Load xcodeproj
    let project: XcodeProj
    do {
      project = try XcodeProj(pathString: xcodeProjectFile.path)
    } catch {
      return .failure(.failedToLoadXcodeProj(xcodeProjectFile, error))
    }

    let projectRootDirectory = xcodeProjectFile.deletingLastPathComponent()
    let sourcesDirectory = outputDirectory.appendingPathComponent("Sources")

    // Extract and convert targets
    return extractTargets(from: project, rootDirectory: projectRootDirectory).flatMap { targets in
      // Copy targets and then create configuration files
      return copyTargets(
        targets,
        to: sourcesDirectory
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
          targets: targets.compactMap { target in
            return target as? ExecutableTarget
          }
        )
      }
    }
  }

  /// Extracts the targets of an xcodeproj.
  /// - Parameters:
  ///   - project: The xcodeproj to extract the targets from.
  ///   - rootDirectory: The Xcode project's root directory.
  /// - Returns: The extracted targets, or a failure if an error occurs.
  static func extractTargets(
    from project: XcodeProj,
    rootDirectory: URL
  ) -> Result<[any XcodeTarget], XcodeprojConverterError> {
    var targets: [any XcodeTarget] = []
    for target in project.pbxproj.nativeTargets {
      let name = target.name

      guard
        let productType = target.productType,
        let targetType = TargetType(productType)
      else {
        log.warning("Only executable and library targets are supported. Skipping '\(name)'")
        continue
      }

      log.info("Loading target '\(name)'")

      // Enumerate the target's source files
      let sources: [XcodeFile]
      do {
        sources = try target.sourceFiles().compactMap { file -> XcodeFile in
          return try XcodeFile.from(file, relativeTo: rootDirectory).unwrap()
        }
      } catch {
        return .failure(.failedToEnumerateSources(target: name, error))
      }

      // Enumerate the target's resource files
      let resources = try? target.resourcesBuildPhase()?.files?.map { file -> XcodeFile in
        return try XcodeFile.from(file, relativeTo: rootDirectory).unwrap()
      }

      let dependencies = target.dependencies.compactMap(\.target?.name)

      // Extract target settings
      let buildSettings = target.buildConfigurationList?.buildConfigurations.first?.buildSettings
      let identifier = buildSettings?["PRODUCT_BUNDLE_IDENTIFIER"] as? String
      let version = buildSettings?["MARKETING_VERSION"] as? String

      if targetType == .executable {
        // Extract the rest of the executable target
        let macOSDeploymentVersion = buildSettings?["MACOSX_DEPLOYMENT_TARGET"] as? String
        var iOSDeploymentVersion = buildSettings?["IPHONEOS_DEPLOYMENT_TARGET"] as? String
        let infoPlistPath = buildSettings?["INFOPLIST_FILE"] as? String

        // iOS deployment version doesn't always seem to be included, so we can just guess if iOS is supported
        if iOSDeploymentVersion == nil && buildSettings?["TARGETED_DEVICE_FAMILY"] != nil {
          iOSDeploymentVersion = "15.0"
          log.warning("Could not find target iOS version, assuming 15.0")
        }

        let evaluate = { (value: String) -> String in
          evaluateBuildSetting(value, targetName: name)
        }

        let infoPlist: URL? = infoPlistPath.map { (path: String) -> URL in
          return rootDirectory.appendingPathComponent(evaluate(path))
        }

        targets.append(ExecutableTarget(
          name: name,
          identifier: identifier.map(evaluate),
          version: version,
          sources: sources,
          resources: resources ?? [],
          dependencies: dependencies,
          macOSDeploymentVersion: macOSDeploymentVersion,
          iOSDeploymentVersion: iOSDeploymentVersion,
          infoPlist: infoPlist
        ))
      } else {
        // Extract the rest of the library target
        targets.append(LibraryTarget(
          name: name,
          identifier: identifier,
          version: version,
          sources: sources,
          resources: resources ?? [],
          dependencies: dependencies
        ))
      }
    }
    
    // Remove empty targets
    targets = targets.filter { target in
      if target.files.isEmpty {
        log.warning("Removing empty target '\(target.name)'")
        return false
      } else {
        return true
      }
    }

    // Remove dependencies that don't exist
    targets = targets.map { target in
      var target = target
      target.dependencies = target.dependencies.filter { dependency in
        if targets.contains(where: { $0.name == dependency }) {
          return true
        } else {
          log.warning("Removing \(target.name)'s dependency on non-existent target '\(dependency)'")
          return false
        }
      }
      return target
    }

    return .success(targets)
  }

  /// Evaluates the Xcode variables (e.g. `$PRODUCT_NAME`) in a build setting string.
  /// - Parameters:
  ///   - value: The value to evaluate variables in.
  ///   - targetName: The name of the target the value is from.
  /// - Returns: The evaluated string, or the original string if there are unknown variables.
  static func evaluateBuildSetting(_ value: String, targetName: String) -> String {
    let result = VariableEvaluator.evaluateVariables(in: value, with: .default(.init(
      appName: targetName,
      productName: targetName
    )))

    switch result {
      case .success(let evaluatedValue):
        return evaluatedValue
      case .failure:
        log.warning("Failed to evaluate variables in '\(value)', you may have to replace some variables manually in 'Bundler.toml'.")
        return value
    }
  }

  /// Copies the given xcodeproj targets into a Swift Bundler project.
  /// - Parameters:
  ///   - targets: The targets to copy.
  ///   - sourcesDirectory: The directory within the Swift Bundler project containing the sources for each target.
  /// - Returns: A failure if an error occurs.
  static func copyTargets(
    _ targets: [XcodeTarget],
    to sourcesDirectory: URL
  ) -> Result<Void, XcodeprojConverterError> {
    for target in targets {
      let result = copyTarget(target, to: sourcesDirectory)

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
  /// - Returns: A failure if an error occurs.
  static func copyTarget(
    _ target: XcodeTarget,
    to sourcesDirectory: URL
  ) -> Result<Void, XcodeprojConverterError> {
    log.info("Copying files for target '\(target.name)'")

    for file in target.files {
      // Get source and destination
      let targetDirectory = sourcesDirectory.appendingPathComponent(target.name)
      let source = file.location
      let destination = targetDirectory.appendingPathComponent(file.bundlerPath(target: target.name))

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
    targets: [ExecutableTarget]
  ) -> Result<Void, XcodeprojConverterError> {
    let configuration: PackageConfiguration
    switch createPackageConfiguration(targets: targets) {
      case .success(let value):
        configuration = value
      case .failure(let error):
        return .failure(error)
    }

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
  static func createPackageConfiguration(
    targets: [ExecutableTarget]
  ) -> Result<PackageConfiguration, XcodeprojConverterError> {
    var apps: [String: AppConfiguration] = [:]
    for target in targets {
      let result = AppConfiguration.create(
        appName: target.name,
        version: target.version ?? "0.1.0",
        identifier: target.identifier ?? "com.example.\(target.name)",
        category: nil,
        infoPlistFile: target.infoPlist,
        iconFile: nil
      )

      switch result {
        case .success(let app):
          apps[target.name] = app
        case .failure(let error):
          return .failure(.failedToCreateAppConfiguration(target: target.name, error))
      }
    }

    return .success(PackageConfiguration(apps))
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
    targets: [any XcodeTarget]
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
  static func createPackageManifestContents(
    packageName: String,
    targets: [any XcodeTarget]
  ) -> String {
    // TODO: Rewrite package manifest generation
    var macOSDeploymentVersion: Version?
    var iOSDeploymentVersion: Version?
    let targetsString = targets.map { target in
      let resourcesString = target.resources.map { file in
        return "                .copy(\"\(file.bundlerPath(target: target.name))\")"
      }.joined(separator: ",\n")

      if let target = target as? ExecutableTarget {
        if let macOSVersionString = target.macOSDeploymentVersion, let macOSVersion = Version(tolerant: macOSVersionString) {
          if let currentVersion = macOSDeploymentVersion, macOSVersion > currentVersion {
            macOSDeploymentVersion = macOSVersion
          } else {
            macOSDeploymentVersion = macOSVersion
          }
        }

        if let iOSVersionString = target.iOSDeploymentVersion, let iOSVersion = Version(tolerant: iOSVersionString) {
          if let currentVersion = iOSDeploymentVersion, iOSVersion > currentVersion {
            iOSDeploymentVersion = iOSVersion
          } else {
            iOSDeploymentVersion = iOSVersion
          }
        }
      }

      return """
        .\(target.targetType.manifestName)(
            name: "\(target.name)",
            dependencies: \(target.dependencies),
            resources: [
\(resourcesString)
            ]
        )
"""
    }.joined(separator: ",\n")

    var platformStrings: [String] = []
    if let macOSDeploymentVersion = macOSDeploymentVersion {
      var versionString = "\(macOSDeploymentVersion.major)"
      if macOSDeploymentVersion.minor != 0 {
        versionString += "_\(macOSDeploymentVersion.minor)"
        if macOSDeploymentVersion.patch != 0 {
          versionString += "_\(macOSDeploymentVersion.patch)"
        }
      }
      platformStrings.append(".macOS(.v\(versionString))")
    }

    if let iOSDeploymentVersion = iOSDeploymentVersion {
      var versionString = "\(iOSDeploymentVersion.major)"
      if iOSDeploymentVersion.minor != 0 {
        versionString += "_\(iOSDeploymentVersion.minor)"
        if iOSDeploymentVersion.patch != 0 {
          versionString += "_\(iOSDeploymentVersion.patch)"
        }
      }
      platformStrings.append(".iOS(.v\(versionString))")
    }

    let packageManifestContents = """
// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "\(packageName)",\(platformStrings == [] ? "" : "\n    platforms: [\(platformStrings.joined(separator: ", "))],")
    dependencies: [],
    targets: [
\(targetsString)
    ]
)
"""

    return packageManifestContents
  }
}
