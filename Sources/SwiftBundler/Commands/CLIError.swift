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
  case invalidXcodeprojDetected
  case failedToResolveTargetDevice(reason: String)
  case failedToResolveCodesigningConfiguration(reason: String)
  case failedToCopyOutBundle(any Error)

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
      case .failedToRemoveExistingOutputs(let outputDirectory, let error):
        return """
          Failed to remove existing bundler outputs at \
          '\(outputDirectory.relativePath): \(error.localizedDescription)'
          """
      case .invalidXcodeprojDetected:
        return
          """
          The --xcodebuild flag, which is the default flag when building any embedded Darwin
          platforms such as iOS, visionOS, tvOS, and watchOS will not function correctly while
          an xcodeproj or xcworkspace is in the same directory as your Package.swift. Please
          remove any .xcodeproj and .xcworkspace directories listed above and try again.

          If you cannot remove the xcodeproj or xcworkspace, you must stick to Swift Bundler's
          default SwiftPM-based build system, you may pass the --no-xcodebuild flag to the bundler
          to override embedded Darwin platforms such as iOS, visionOS, tvOS, and watchOS to use the
          SwiftPM-based build system instead of the xcodebuild one.
          """
      case .failedToResolveTargetDevice(let reason):
        return "Failed to resolve target device: \(reason)"
      case .failedToResolveCodesigningConfiguration(let reason):
        return "Failed to resolve codesigning configuration: \(reason)"
      case .failedToCopyOutBundle(let reason):
        return "Failed to copy out bundle: \(reason.localizedDescription)"
    }
  }
}
