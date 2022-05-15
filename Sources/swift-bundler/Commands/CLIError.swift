import Foundation

/// An error thrown by the Swift Bundler CLI.
enum CLIError: LocalizedError {
  case invalidPlatform(String)
  case invalidArchitecture(String)
  case invalidBuildConfiguration(String)
  case missingMinimumMacOSVersion
  case missingMinimumIOSVersion
  case failedToAutomaticallyUpdateTemplates(Error)

  var errorDescription: String? {
    switch self {
      case .invalidPlatform(let platform):
        return "Invalid platform '\(platform)'. Must be one of (macOS|iOS)"
      case .invalidArchitecture(let architecture):
        return "Invalid architecture '\(architecture)'. Must be one of \(BuildArchitecture.possibleValuesString)"
      case .invalidBuildConfiguration(let buildConfiguration):
        return "Invalid build configuration '\(buildConfiguration)'. Must be one of \(BuildConfiguration.possibleValuesString)"
      case .missingMinimumMacOSVersion:
        return "'minimum_macos_version' must be specified in Bundler.toml to build for platform 'macOS'"
      case .missingMinimumIOSVersion:
        return "'minimum_ios_version' must be specified in Bundler.toml to build for platform 'iOS'"
      case .failedToAutomaticallyUpdateTemplates(let error):
        return "Failed to automatically update your templates. Use the '--skip-update' flag to continue anyway. Details: \(error.localizedDescription)"
    }
  }
}
