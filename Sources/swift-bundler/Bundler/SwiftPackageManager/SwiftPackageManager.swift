import Foundation
import ArgumentParser
import Version
import Parsing

/// A utility for interacting with the Swift package manager and performing some other package related operations.
enum SwiftPackageManager {
  /// The path to the swift executable.
  static let swiftExecutable = "/usr/bin/swift"

  /// Creates a new package using the given directory as the package's root directory.
  /// - Parameters:
  ///   - directory: The package's root directory (will be created if it doesn't exist).
  ///   - name: The name for the package.
  /// - Returns: If an error occurs, a failure is returned.
  static func createPackage(
    in directory: URL,
    name: String
  ) -> Result<Void, SwiftPackageManagerError> {
    // Create the package directory if it doesn't exist
    let createPackageDirectory: () -> Result<Void, SwiftPackageManagerError> = {
      if !FileManager.default.itemExists(at: directory, withType: .directory) {
        do {
          try FileManager.default.createDirectory(at: directory)
        } catch {
          return .failure(.failedToCreatePackageDirectory(directory, error))
        }
      }
      return .success()
    }

    // Run the init command
    let runInitCommand: () -> Result<Void, SwiftPackageManagerError> = {
      let arguments = [
        "package", "init",
        "--type=executable",
        "--name=\(name)"
      ]

      let process = Process.create(
        Self.swiftExecutable,
        arguments: arguments,
        directory: directory)
      process.setOutputPipe(Pipe())

      return process.runAndWait()
        .mapError { error in
          .failedToRunSwiftInit(command: "\(Self.swiftExecutable) \(arguments.joined(separator: " "))", error)
        }
    }

    // Create the configuration file
    let createConfigurationFile: () -> Result<Void, SwiftPackageManagerError> = {
      Configuration.createConfigurationFile(in: directory, app: name, product: name)
        .mapError { error in
          .failedToCreateConfigurationFile(error)
        }
    }

    // Compose the function
    let create = flatten(
      createPackageDirectory,
      runInitCommand,
      createConfigurationFile)

    return create()
  }

  /// Builds the specified product of a Swift package.
  /// - Parameters:
  ///   - product: The product to build.
  ///   - packageDirectory: The root directory of the package containing the product.
  ///   - configuration: The build configuration to use.
  ///   - architectures: The set of architectures to build for.
  /// - Returns: If an error occurs, returns a failure.
  static func build(
    product: String,
    packageDirectory: URL,
    configuration: BuildConfiguration,
    architectures: [BuildArchitecture]
  ) -> Result<Void, SwiftPackageManagerError> {
    log.info("Starting \(configuration.rawValue) build")

    let arguments = [
      "build",
      "-c", configuration.rawValue,
      "--product", product
    ] + architectures.flatMap {
      ["--arch", $0.rawValue]
    }

    let process = Process.create(
      Self.swiftExecutable,
      arguments: arguments,
      directory: packageDirectory)

    return process.runAndWait()
      .mapError { error in
        .failedToRunSwiftBuild(command: "\(Self.swiftExecutable) \(arguments.joined(separator: " "))", error)
      }
  }

  /// Gets the device's target triple.
  /// - Returns: The device's target triple. If an error occurs, a failure is returned.
  static func getSwiftTargetTriple() -> Result<String, SwiftPackageManagerError> {
    let process = Process.create(
      "/usr/bin/swift",
      arguments: ["-print-target-info"])

    return process.getOutputData()
      .mapError { error in
        .failedToGetTargetTriple(error)
      }
      .flatMap { output in
        let unversionedTriple: String
        do {
          let targetInfo = try JSONDecoder().decode(SwiftTargetInfo.self, from: output)
          unversionedTriple = targetInfo.target.unversionedTriple
        } catch {
          return .failure(.failedToDeserializeTargetInfo(output, error))
        }

        return .success(unversionedTriple)
      }
  }

  /// Gets the version of the current Swift installation.
  /// - Returns: The swift version, or a failure if an error occurs.
  static func getSwiftVersion() -> Result<Version, SwiftPackageManagerError> {
    let process = Process.create(
      "/usr/bin/swift",
      arguments: ["--version"])

    return process.getOutput()
      .mapError { error in
        .failedToGetSwiftVersion(error)
      }
      .flatMap { output in
        // Sample: "swift-driver version: 1.45.2 Apple Swift version 5.6 (swiftlang-5.6.0.323.62 clang-1316.0.20.8)"
        let parser = Parse {
          Prefix { $0 != "(" }
          "(swiftlang-"
          Parse({ Version.init(major: $0, minor: $1, patch: $2) }) {
            Int.parser()
            "."
            Int.parser()
            "."
            Int.parser()
          }
          Rest()
        }.map { _, version, _ in
          version
        }

        do {
          let version = try parser.parse(output)
          return .success(version)
        } catch {
          return .failure(.invalidSwiftVersionOutput(output, error))
        }
      }
  }

  /// Gets the default products directory for the specified package and configuration.
  /// - Parameters:
  ///   - packageDirectory: The package's root directory.
  ///   - buildConfiguration: The current build configuration.
  ///   - architectures: The architectures that the build was for.
  /// - Returns: The default products directory. If ``getSwiftTargetTriple()`` fails, a failure is returned.
  static func getProductsDirectory(
    in packageDirectory: URL,
    buildConfiguration: BuildConfiguration,
    architectures: [BuildArchitecture]
  ) -> Result<URL, SwiftPackageManagerError> {
    if architectures.count == 1 {
      let architecture = architectures[0]
      return getSwiftTargetTriple()
        .map { targetTriple in
          let targetTriple = targetTriple.replacingOccurrences(of: BuildArchitecture.current.rawValue, with: architecture.rawValue)
          return packageDirectory
            .appendingPathComponent(".build")
            .appendingPathComponent(targetTriple)
            .appendingPathComponent(buildConfiguration.rawValue)
        }
    } else {
      return .success(packageDirectory
        .appendingPathComponent(".build/apple/Products")
        .appendingPathComponent(buildConfiguration.rawValue.capitalized))
    }
  }
}
