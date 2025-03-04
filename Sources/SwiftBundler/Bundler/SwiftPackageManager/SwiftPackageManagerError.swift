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
  case failedToRunSwiftPackageDescribe(command: String, ProcessError)
  case failedToParsePackageManifestOutput(json: String, Error?)
  case failedToParsePackageManifestToolsVersion(Error?)
  case failedToReadBuildPlan(path: URL, Error)
  case failedToDecodeBuildPlan(Error)
  case failedToComputeLinkingCommand(details: String)
  case failedToRunLinkingCommand(command: String, Error)
  case missingDarwinPlatformVersion(Platform)
  case failedToGetToolsVersion(ProcessError)
  case invalidToolsVersion(String)

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
      case .failedToRunSwiftPackageDescribe(let command, let error):
        return "Failed to run '\(command)': \(error.localizedDescription)"
      case .failedToParsePackageManifestOutput(_, let error):
        // 'Unknown error' means failed to convert string to data, but I didn't want to
        // make that weak assumption about the implementation
        return
          "Failed to parse package manifest output: \(error?.localizedDescription ?? "Unknown error")"
      case .failedToParsePackageManifestToolsVersion(let error):
        return """
          Failed to parse package manifest tools version: \
          \(error?.localizedDescription ?? "Unknown error")
          """
      case .failedToReadBuildPlan(let path, let error):
        let buildPlan = path.path(relativeTo: URL(fileURLWithPath: "."))
        return """
          Failed to read build plan file at '\(buildPlan)': \
          \(error.localizedDescription)
          """
      case .failedToDecodeBuildPlan(let error):
        return "Failed to decode build plain: \(error.localizedDescription)"
      case .failedToComputeLinkingCommand(let details):
        return "Failed to compute linking command: \(details)"
      case .failedToRunLinkingCommand(let command, let error):
        return "Failed to run linking commmand '\(command)': \(error.localizedDescription)"
      case .missingDarwinPlatformVersion(let platform):
        return """
          Missing target platform version for '\(platform.rawValue)' in \
          'Package.swift'. Please update the `Package.platforms` array \
          and try again. Building for Darwin platforms requires a target \
          platform.
          """
      case .failedToGetToolsVersion(let error):
        return """
          Failed to get Swift package manifest tools version: \
          \(error.localizedDescription)
          """
      case .invalidToolsVersion(let version):
        return "Invalid Swift tools version '\(version)' (expected a semantic version)"
    }
  }
}
