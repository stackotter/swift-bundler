import Foundation

/// An error thrown by the Swift Bundler CLI.
enum CLIError: LocalizedError {
  case invalidPlatform(String)
  case invalidArchitecture(String)
  case invalidBuildConfiguration(String)
  case failedToCopyIcon(source: URL, destination: URL, Error)
  case failedToGetPlatformVersion(platform: Platform, manifest: URL)

  var errorDescription: String? {
    switch self {
      case .invalidPlatform(let platform):
        return "Invalid platform '\(platform)'. Must be one of (macOS|iOS)"
      case .invalidArchitecture(let architecture):
        return "Invalid architecture '\(architecture)'. Must be one of \(BuildArchitecture.possibleValuesString)"
      case .invalidBuildConfiguration(let buildConfiguration):
        return "Invalid build configuration '\(buildConfiguration)'. Must be one of \(BuildConfiguration.possibleValuesString)"
      case .failedToCopyIcon(let source, let destination, _):
        return "Failed to copy icon from '\(source)' to '\(destination)'"
    case .failedToGetPlatformVersion(let platform, let manifest):
        return "To build for \(platform.name) you must specify a minimum deployment version in the 'platforms' field of '\(manifest.relativePath)'"
    }
  }
}
