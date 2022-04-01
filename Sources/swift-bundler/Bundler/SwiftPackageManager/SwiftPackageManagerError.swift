import Foundation

/// An error returned by ``SwiftPackageManager``.
enum SwiftPackageManagerError: LocalizedError, CustomDebugStringConvertible {
  case failedToRunSwiftBuild(command: String, ProcessError)
  case failedToGetTargetTriple(ProcessError)
  case failedToDeserializeTargetInfo(Data, Error)
  case failedToCreatePackageDirectory(URL, Error)
  case failedToRunSwiftInit(command: String, ProcessError)
  case failedToCreateConfigurationFile(ConfigurationError)
  case failedToGetSwiftVersion(ProcessError)
  case invalidSwiftVersionOutput(String, Error)

  var errorDescription: String? {
    switch self {
      case .failedToRunSwiftBuild(let command, let processError):
        return "Failed to run '\(command)': \(processError.localizedDescription)"
      case .failedToGetTargetTriple(let processError):
        return "Failed to get target triple: \(processError.localizedDescription)"
      case .failedToDeserializeTargetInfo:
        return "Failed to deserialize target platform info"
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
    }
  }

  var debugDescription: String {
    switch self {
      case .failedToDeserializeTargetInfo(let data, let error):
        let string = String(data: data, encoding: .utf8) ?? "Invalid utf-8: \(data.debugDescription)"
        return "\(string), \(error)"
      default:
        return Mirror(reflecting: self).description
    }
  }
}
