import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder
import TOMLKit
import Version

#if SUPPORT_XCODEPROJ
  import XcodeProj
#endif

/// A utility for converting xcodeproj's to Swift Bundler projects.
enum XcodeprojConverter {
  static func convertWorkspace(
    _ xcodeWorkspaceFile: URL,
    outputDirectory: URL
  ) async -> Result<Void, XcodeprojConverterError> {
    #if SUPPORT_XCODEPROJ
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

        let result = await convertProject(
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
    #else
      return .failure(.hostPlatformNotSupported)
    #endif
  }

  /// Converts an xcodeproj to a Swift Bundler project.
  /// - Parameters:
  ///   - xcodeProjectFile: The xcodeproj to convert.
  ///   - outputDirectory: The Swift Bundler project's directory.
  /// - Returns: A failure if an error occurs.
  static func convertProject(
    _ xcodeProjectFile: URL,
    outputDirectory: URL
  ) async -> Result<Void, XcodeprojConverterError> {
    #if SUPPORT_XCODEPROJ
      // Ensure that output directory doesn't already exist
      guard !FileManager.default.fileExists(atPath: outputDirectory.path) else {
        return .failure(.directoryAlreadyExists(outputDirectory))
      }

      let projectRootDirectory = xcodeProjectFile.deletingLastPathComponent()
      let sourcesDirectory = outputDirectory.appendingPathComponent("Sources")

      // Load xcodeproj
      return await Result {
        try XcodeProj(pathString: xcodeProjectFile.path)
      }
      .mapError { error in
        .failedToLoadXcodeProj(xcodeProjectFile, error)
      }
      .andThen { project in
        // Extract and convert targets
        await extractTargets(from: project, rootDirectory: projectRootDirectory)
      }
      .andThen { targets in
        // Copy targets and then create configuration files
        copyTargets(
          targets,
          to: sourcesDirectory
        ).andThen { _ in
          // Create Package.swift
          createPackageManifestFile(
            at: outputDirectory.appendingPathComponent("Package.swift"),
            packageName: xcodeProjectFile.deletingPathExtension().lastPathComponent,
            targets: targets
          )
        }.andThen { _ in
          // Create Bundler.toml
          createPackageConfigurationFile(
            at: outputDirectory.appendingPathComponent("Bundler.toml"),
            targets: targets.compactMap { target in
              target as? ExecutableTarget
            }
          )
        }
      }
    #else
      return .failure(.hostPlatformNotSupported)
    #endif
  }

  #if SUPPORT_XCODEPROJ
    /// Extracts the packages that a target depends on. Ignores package dependencies that it doesn't understand.
    /// - Parameters:
    ///   - target: The Xcode target to extract the package dependencies from.
    ///   - rootDirectory: The Xcode project's root directory
    /// - Returns: All of the Xcode target's valid package dependencies.
    private static func extractPackageDependencies(
      from target: PBXNativeTarget,
      rootDirectory: URL
    ) -> [XcodePackageDependency] {
      var packageDependencies: [XcodePackageDependency] = []

      for dependency in target.packageProductDependencies {
        guard
          let package = dependency.package,
          let packageName = package.name,
          let url = package.repositoryURL,
          let version = package.versionRequirement
        else {
          continue
        }

        let absoluteURL: URL
        if url.hasPrefix("https://") || url.hasPrefix("http://") || url.hasPrefix("git://") {
          guard let url = URL(string: url) else {
            log.warning("Skipping package dependency with invalid url '\(url)'")
            continue
          }
          absoluteURL = url
        } else if url.hasPrefix("/") {
          absoluteURL = URL(fileURLWithPath: url)
        } else {
          absoluteURL = rootDirectory.appendingPathComponent(url)
        }

        packageDependencies.append(
          XcodePackageDependency(
            product: dependency.productName,
            package: packageName,
            url: absoluteURL,
            version: version
          )
        )
      }

      return packageDependencies
    }

    /// Extracts the targets of an Xcode project.
    /// - Parameters:
    ///   - project: The Xcode project to extract the targets from.
    ///   - packageDependencies: The project's package dependencies.
    ///   - rootDirectory: The Xcode project's root directory.
    /// - Returns: The extracted targets, or a failure if an error occurs.
    private static func extractTargets(
      from project: XcodeProj,
      rootDirectory: URL
    ) async -> Result<([any XcodeTarget]), XcodeprojConverterError> {
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
        let packageDependencies = extractPackageDependencies(
          from: target,
          rootDirectory: rootDirectory
        )

        // Extract target settings
        let buildSettings = target.buildConfigurationList?.buildConfigurations.first?.buildSettings
        let identifier = buildSettings?["PRODUCT_BUNDLE_IDENTIFIER"] as? String
        let version = buildSettings?["MARKETING_VERSION"] as? String

        if targetType == .executable {
          // Extract the rest of the executable target
          let macOSDeploymentVersion = buildSettings?["MACOSX_DEPLOYMENT_TARGET"] as? String
          var iOSDeploymentVersion = buildSettings?["IPHONEOS_DEPLOYMENT_TARGET"] as? String
          let visionOSDeploymentVersion = buildSettings?["XROS_DEPLOYMENT_TARGET"] as? String
          let infoPlistPath = buildSettings?["INFOPLIST_FILE"] as? String

          // iOS deployment version doesn't always seem to be included, so we can just guess if iOS is supported
          if iOSDeploymentVersion == nil && buildSettings?["TARGETED_DEVICE_FAMILY"] != nil {
            iOSDeploymentVersion = "15.0"
            log.warning("Could not find target iOS version, assuming 15.0")
          }

          let evaluate = { (value: String) async -> String in
            await evaluateBuildSetting(value, targetName: name)
          }

          let infoPlist: URL? = await infoPlistPath.asyncMap { (path: String) -> URL in
            return await rootDirectory.appendingPathComponent(evaluate(path))
          }

          await targets.append(
            ExecutableTarget(
              name: name,
              identifier: identifier.asyncMap(evaluate),
              version: version,
              sources: sources,
              resources: resources ?? [],
              dependencies: dependencies,
              packageDependencies: packageDependencies,
              macOSDeploymentVersion: macOSDeploymentVersion,
              iOSDeploymentVersion: iOSDeploymentVersion,
              visionOSDeploymentVersion: visionOSDeploymentVersion,
              infoPlist: infoPlist
            )
          )
        } else {
          // Extract the rest of the library target
          targets.append(
            LibraryTarget(
              name: name,
              identifier: identifier,
              version: version,
              sources: sources,
              resources: resources ?? [],
              dependencies: dependencies,
              packageDependencies: packageDependencies
            )
          )
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
            log.warning(
              "Removing \(target.name)'s dependency on non-existent target '\(dependency)'")
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
    private static func evaluateBuildSetting(_ value: String, targetName: String) async -> String {
      let result = await VariableEvaluator.evaluateVariables(
        in: value,
        with: .default(
          .init(
            appName: targetName,
            productName: targetName,
            date: Date()
          )
        )
      )

      switch result {
        case .success(let evaluatedValue):
          return evaluatedValue
        case .failure:
          log.warning(
            "Failed to evaluate variables in '\(value)', you may have to replace some variables manually in 'Bundler.toml'."
          )
          return value
      }
    }

    /// Copies the given xcodeproj targets into a Swift Bundler project.
    /// - Parameters:
    ///   - targets: The targets to copy.
    ///   - sourcesDirectory: The directory within the Swift Bundler project containing the sources for each target.
    /// - Returns: A failure if an error occurs.
    private static func copyTargets(
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
    private static func copyTarget(
      _ target: XcodeTarget,
      to sourcesDirectory: URL
    ) -> Result<Void, XcodeprojConverterError> {
      log.info("Copying files for target '\(target.name)'")

      // Create directory for target and copy files across.
      let targetDirectory = sourcesDirectory.appendingPathComponent(target.name)
      return FileManager.default.createDirectory(at: targetDirectory)
        .mapError { error in
          .failedToCreateTargetDirectory(target: target.name, targetDirectory, error)
        }
        .andThen { _ in
          target.files.tryForEach { file in
            // Get source and destination
            let source = file.location
            let destination = targetDirectory.appendingPathComponent(
              file.bundlerPath(target: target.name)
            )
            let destinationDirectory = destination.deletingLastPathComponent()
            let destinationExists = FileManager.default.itemExists(
              at: destinationDirectory,
              withType: .directory
            )

            // Create parent directory if required and copy item.
            return Result.success()
              .andThen(if: !destinationExists) {
                FileManager.default.createDirectory(at: destinationDirectory)
              }
              .andThen { _ in
                FileManager.default.copyItem(at: source, to: destination)
              }
              .mapError { error in
                .failedToCopyFile(source: source, destination: destination, error)
              }
          }
        }
    }

    /// Creates a `Bundler.toml` file declaring the given executable targets as apps.
    /// - Parameters:
    ///   - file: The location to create the file at.
    ///   - targets: The executable targets to add as apps.
    /// - Returns: A failure if an error occurs.
    private static func createPackageConfigurationFile(
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
    private static func createPackageConfiguration(
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

      return .success(PackageConfiguration(apps: apps))
    }

    /// Creates a `Package.swift` file declaring the given targets.
    /// - Parameters:
    ///   - file: The location to create the file at.
    ///   - packageName: The name to give the package.
    ///   - targets: The targets to declare.
    /// - Returns: A failure if an error occurs.
    private static func createPackageManifestFile(
      at file: URL,
      packageName: String,
      targets: [any XcodeTarget]
    ) -> Result<Void, XcodeprojConverterError> {
      createPackageManifestContents(
        packageName: packageName,
        targets: targets
      ).andThen { contents in
        contents.write(to: file)
          .mapError { error in
            .failedToCreatePackageManifest(file, error)
          }
      }
    }

    /// Creates the contents of a `Package.swift` file declaring the given targets.
    /// - Parameters:
    ///   - packageName: The package's name.
    ///   - targets: The targets to declare.
    /// - Returns: The generated contents.
    private static func createPackageManifestContents(
      packageName: String,
      targets: [any XcodeTarget]
    ) -> Result<String, XcodeprojConverterError> {
      let platformStrings = minimalPlatformStrings(for: targets)

      var names: Set<String> = []
      let uniquePackageDependencies = targets.flatMap { target in
        target.packageDependencies
      }.filter { dependency in
        return names.insert(dependency.package).inserted
      }

      func stringLiteral(_ value: String) -> String {
        ExprSyntax("\(literal: value)").description
      }

      let indentSpaces = 4

      func indent(
        _ expression: String,
        amount indentLevel: Int,
        skipFirstLine: Bool = false
      ) -> String {
        let indentation = String(repeating: " ", count: indentLevel * indentSpaces)
        return expression.split(separator: "\n").enumerated().map { (index, line) in
          if skipFirstLine && index == 0 {
            return line
          } else {
            return indentation + line
          }
        }.joined(separator: "\n")
      }

      func arrayLiteral(_ elementExpressions: [String]) -> String {
        if elementExpressions.isEmpty {
          return "[]"
        } else {
          return """
            [
            \(elementExpressions.map { indent($0, amount: 1) }.joined(separator: ",\n"))
            ]
            """
        }
      }

      let dependenciesSource = arrayLiteral(
        uniquePackageDependencies.map { dependency in
          let url = dependency.url.absoluteString
          let requirement = dependency.requirementParameterSource
          return """
            .package(
                url: \(stringLiteral(url)),
                \(requirement)
            )
            """
        }
      )

      let targetsSource = arrayLiteral(
        targets.map { target in
          let targetDependencies =
            target.dependencies.map { dependency in
              stringLiteral(dependency)
            }
            + target.packageDependencies.map { dependency in
              ".product(name: \(stringLiteral(dependency.product)), package: \(stringLiteral(dependency.package)))"
            }
          let targetDependenciesSource = arrayLiteral(targetDependencies)

          let resourcesSource = arrayLiteral(
            target.resources.map { resource in
              let path = resource.bundlerPath(target: target.name)
              return ".copy(\(stringLiteral(path)))"
            }
          )

          return """
            .\(target.targetType.manifestName)(
                name: \(stringLiteral(target.name)),
                dependencies: \(indent(targetDependenciesSource, amount: 1, skipFirstLine: true)),
                resources: \(indent(resourcesSource, amount: 1, skipFirstLine: true))
            )
            """
        }
      )

      let source = """
        // swift-tools-version: 5.9

        import PackageDescription

        let package = Package(
            name: \(stringLiteral(packageName)),
            platforms: \(platformStrings == [] ? "[]" : "[\(platformStrings.joined(separator: ", "))]"),
            dependencies: \(indent(dependenciesSource, amount: 1, skipFirstLine: true)),
            targets: \(indent(targetsSource, amount: 1, skipFirstLine: true))
        )
        """

      return .success(source)
    }

    private static func minimalPlatformStrings(for targets: [any XcodeTarget]) -> [String] {
      let executableTargets = targets.compactMap { target in
        return target as? ExecutableTarget
      }

      let macOSDeploymentVersion: Version? =
        executableTargets
        .compactMap(\.macOSDeploymentVersion)
        .compactMap(Version.init(tolerant:))
        .max()

      let iOSDeploymentVersion: Version? =
        executableTargets
        .compactMap(\.iOSDeploymentVersion)
        .compactMap(Version.init(tolerant:))
        .max()

      let visionOSDeploymentVersion: Version? =
        executableTargets
        .compactMap(\.visionOSDeploymentVersion)
        .compactMap(Version.init(tolerant:))
        .max()

      var platformStrings: [String] = []
      if let version = macOSDeploymentVersion?.underscoredMinimal {
        platformStrings.append(".macOS(.v\(version))")
      }

      if var version = iOSDeploymentVersion?.underscoredMinimal {
        if iOSDeploymentVersion?.major == 15 {
          version = "15"
        }
        platformStrings.append(".iOS(.v\(version))")
      }

      if var version = visionOSDeploymentVersion?.underscoredMinimal {
        if visionOSDeploymentVersion?.major == 1 {
          version = "1"
        }
        platformStrings.append(".visionOS(.v\(version))")
      }

      return platformStrings
    }
  #endif
}
