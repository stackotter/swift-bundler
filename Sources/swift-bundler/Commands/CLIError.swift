import Foundation

/// An error thrown by the Swift Bundler CLI.
enum CLIError: LocalizedError {
  case invalidPlatform(String)
  case invalidArchitecture(String)
  case invalidBuildConfiguration(String)
  case invalidBundlerChoice(String)
  case failedToCopyIcon(source: URL, destination: URL, Error)
  case failedToGetPlatformVersion(platform: Platform, manifest: URL)
  case failedToRemoveExistingOutputs(outputDirectory: URL, Error)

  var errorDescription: String? {
    switch self {
      case .invalidPlatform(let platform):
        return """
          Invalid platform '\(platform)'. Must be one of \
          \(Platform.possibleValuesDescription)
          """
      case .invalidArchitecture(let architecture):
        return """
          Invalid architecture '\(architecture)'. Must be one of \
          \(BuildArchitecture.possibleValuesDescription)
          """
      case .invalidBuildConfiguration(let buildConfiguration):
        return """
          Invalid build configuration '\(buildConfiguration)'. Must be one of \
          \(BuildConfiguration.possibleValuesDescription)
          """
      case .invalidBundlerChoice(let choice):
        return """
          Invalid bundler choice '\(choice)'. Must be one of \
          \(BundlerChoice.possibleValuesDescription)
          """
      case .failedToCopyIcon(let source, let destination, _):
        return "Failed to copy icon from '\(source)' to '\(destination)'"
      case .failedToGetPlatformVersion(let platform, let manifest):
        return """
          To build for \(platform.name) you must specify a minimum deployment \
          version for the relevant platform in the 'platforms' field of \
          '\(manifest.relativePath)'
          """
      case .failedToRemoveExistingOutputs(let outputDirectory, _):
        return """
          Failed to remove existing bundler outputs at \
          '\(outputDirectory.relativePath)'
          """
    }
  }
}
