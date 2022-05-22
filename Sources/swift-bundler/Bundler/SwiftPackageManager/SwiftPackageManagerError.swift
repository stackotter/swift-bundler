import Foundation
import Basics

/// An error returned by ``SwiftPackageManager``.
enum SwiftPackageManagerError: LocalizedError {
  case failedToRunSwiftBuild(command: String, ProcessError)
  case failedToCreatePackageDirectory(URL, Error)
  case failedToRunSwiftInit(command: String, ProcessError)
  case failedToCreateConfigurationFile(PackageConfigurationError)
  case failedToGetSwiftVersion(ProcessError)
  case invalidSwiftVersionOutput(String, Error)
  case failedToGetProductsDirectory(command: String, ProcessError)
  case failedToGetLatestSDKPath(Platform, ProcessError)
  case failedToLoadPackageManifest(directory: URL, [Diagnostic], Error)

  var errorDescription: String? {
    switch self {
      case .failedToRunSwiftBuild(let command, let processError):
        return "Failed to run '\(command)': \(processError.localizedDescription)"
      case .failedToCreatePackageDirectory(let directory, _):
        return "Failed to create package directory at '\(directory.relativePath)'"
      case .failedToRunSwiftInit(let command, let processError):
        return "Failed to run '\(command)': \(processError.localizedDescription)"
      case .failedToCreateConfigurationFile(let configurationError):
        return "Failed to create configuration file: \(configurationError.localizedDescription)"
      case .failedToGetSwiftVersion(let processError):
        return "Failed to get Swift version: \(processError.localizedDescription)"
      case .invalidSwiftVersionOutput(let output, _):
        return "The output of 'swift --version' could not be parsed: '\(output)'"
      case .failedToGetProductsDirectory(let command, let error):
        return "Failed to get products directory via '\(command)': \(error.localizedDescription)"
      case .failedToGetLatestSDKPath(let platform, let error):
        return "Failed to get latest \(platform.rawValue) SDK path: \(error.localizedDescription)"
      case .failedToLoadPackageManifest(let directory, let diagnostics, _):
        let diagnosticsString = diagnostics.map(\.description).map({ $0 + "\n" }).joined(separator: "")
        return "\(diagnosticsString)Failed to load package manifest from '\(directory)'"
    }
  }
}
