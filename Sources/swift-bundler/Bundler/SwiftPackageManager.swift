import Foundation

enum SwiftPackageManagerError: LocalizedError {
  case failedToRunSwiftBuild(ProcessError)
  case failedToGetTargetTriple(ProcessError)
  case failedToDeserializeTargetInfo(Error)
  case invalidTargetInfoJSONFormat
  case failedToCreatePackageDirectory(Error)
  case failedToRunInitCommand(ProcessError)
  case failedToCreateConfigurationFile(ConfigurationError)
}

/// A utility for interacting with the Swift package manager and performing some other package related operations.
enum SwiftPackageManager {
  enum BuildConfiguration: String {
    case debug
    case release
  }
  
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
          return .failure(.failedToCreatePackageDirectory(error))
        }
      }
      return .success()
    }
    
    // Run the init command
    let runInitCommand: () -> Result<Void, SwiftPackageManagerError> = {
      let process = Process.create(
        "/usr/bin/swift",
        arguments: [
          "package", "init",
          "--type=executable",
          "--name=\(name)"
        ],
        directory: directory)
      
      return process.runAndWait()
        .mapError { error in
          .failedToRunInitCommand(error)
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
  ///   - universal: If `true`, performs a universal build.
  /// - Returns: If an error occurs, returns a failure.
  static func build(
    product: String,
    packageDirectory: URL,
    configuration: SwiftPackageManager.BuildConfiguration,
    universal: Bool
  ) -> Result<Void, SwiftPackageManagerError> {
    log.info("Starting \(configuration.rawValue) build")
    
    var arguments = [
      "build",
      "-c", configuration.rawValue,
      "--product", product]
    if universal {
      arguments += ["--arch", "arm64", "--arch", "x86_64"]
    }
    
    let process = Process.create(
      "/usr/bin/swift",
      arguments: arguments,
      directory: packageDirectory)
    
    return process.runAndWait()
      .mapError { error in
        .failedToRunSwiftBuild(error)
      }
  }
  
  /// Gets the device's target triple.
  /// - Returns: The device's target triple.
  static func getSwiftTargetTriple() -> Result<String, SwiftPackageManagerError> {
    let process = Process.create(
      "/usr/bin/swift",
      arguments: ["-print-target-info"])
    
    return process.getOutputData()
      .mapError { error in
        .failedToGetTargetTriple(error)
      }
      .flatMap { output in
        let object: Any
        do {
          object = try JSONSerialization.jsonObject(
            with: output,
            options: [])
        } catch {
          return .failure(.failedToDeserializeTargetInfo(error))
        }
        
        guard
          let dictionary = object as? [String: Any],
          let targetDictionary = dictionary["target"] as? [String: Any],
          let unversionedTriple = targetDictionary["unversionedTriple"] as? String
        else {
          return .failure(.invalidTargetInfoJSONFormat)
        }
        
        return .success(unversionedTriple)
      }
  }
  
  /// Gets the default products directory for the specified package and configuration.
  /// - Parameters:
  ///   - packageDirectory: The package's root directory.
  ///   - buildConfiguration: The current build configuration.
  static func getDefaultProductsDirectory(in packageDirectory: URL, buildConfiguration: BuildConfiguration) -> Result<URL, SwiftPackageManagerError> {
    return getSwiftTargetTriple()
      .map { targetTriple in
        packageDirectory
          .appendingPathComponent(".build")
          .appendingPathComponent(targetTriple)
          .appendingPathComponent(buildConfiguration.rawValue)
      }
  }
}
