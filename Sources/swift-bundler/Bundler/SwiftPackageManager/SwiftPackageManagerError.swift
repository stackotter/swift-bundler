import Foundation

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
  case failedToGetTargetInfo(command: String, ProcessError)
  case failedToParseTargetInfo(json: String, Error?)
  case failedToCompilePackageManifest(Error)
  case failedToExtractManifestAutolinkInfo(Error)
  case failedToLinkPackageManifest(Error)
  case failedToExecutePackageManifest(Error)
  case failedToParsePackageManifestOutput(json: String, Error?)
  case failedToParsePackageManifestToolsVersion(Error?)

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
      case .failedToGetTargetInfo(let command, let error):
        return "Failed to get target info via '\(command)': \(error.localizedDescription)"
      case .failedToParseTargetInfo(_, let error):
        // 'Unknown error' means failed to convert string to data, but I didn't want to
        // make that weak assumption about the implementation
        return
          "Failed to parse Swift target info: \(error?.localizedDescription ?? "Unknown error")"
      case .failedToCompilePackageManifest(let error):
        return "Failed to compile package manifest: \(error.localizedDescription)"
      case .failedToExtractManifestAutolinkInfo(let error):
        return
          "Failed to extract autolink info from Package manifest object file: \(error.localizedDescription)"
      case .failedToLinkPackageManifest(let error):
        return "Failed to link package manifest: \(error.localizedDescription)"
      case .failedToExecutePackageManifest(let error):
        return "Failed to execute package manifest: \(error.localizedDescription)"
      case .failedToParsePackageManifestOutput(_, let error):
        // 'Unknown error' means failed to convert string to data, but I didn't want to
        // make that weak assumption about the implementation
        return
          "Failed to parse package manifest output: \(error?.localizedDescription ?? "Unknown error")"
      case .failedToParsePackageManifestToolsVersion(let error):
        return """
          Failed to parse package manifest tools version: \(error?.localizedDescription ?? "Unknown error")
          """
    }
  }
}
