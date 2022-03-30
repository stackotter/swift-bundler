import Foundation

/// An error returned by ``SwiftPackageManager``.
enum SwiftPackageManagerError: LocalizedError {
  case failedToRunSwiftBuild(command: String, ProcessError)
  case failedToGetTargetTriple(ProcessError)
  case failedToDeserializeTargetInfo(Error)
  case invalidTargetInfoJSONFormat
  case failedToCreatePackageDirectory(URL, Error)
  case failedToRunSwiftInit(command: String, ProcessError)
  case failedToCreateConfigurationFile(ConfigurationError)
  
  var errorDescription: String? {
    switch self {
      case .failedToRunSwiftBuild(let command, let processError):
        return "Failed to run '\(command)': \(processError.localizedDescription)"
      case .failedToGetTargetTriple(let processError):
        return "Failed to get target triple through swift cli: \(processError.localizedDescription)"
      case .failedToDeserializeTargetInfo(_):
        return "Failed to deserialize target platform info from swift cli"
      case .invalidTargetInfoJSONFormat:
        return "Target platform info could not be parsed"
      case .failedToCreatePackageDirectory(let directory, _):
        return "Failed to create package directory at '\(directory.relativePath)'"
      case .failedToRunSwiftInit(let command, let processError):
        return "Failed to run '\(command)': \(processError.localizedDescription)"
      case .failedToCreateConfigurationFile(let configurationError):
        return "Failed to create configuration file: \(configurationError.localizedDescription)"
    }
  }
}
