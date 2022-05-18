import Foundation

/// An error related to the configuration of a specific app.
enum AppConfigurationError: LocalizedError {
  case failedToLoadInfoPlistEntries(file: URL, error: PlistError)

  var errorDescription: String? {
    switch self {
      case .failedToLoadInfoPlistEntries(let file, let error):
        return "Failed to load '\(file.relativePath)' for appending to app configuration: \(error.localizedDescription)"
    }
  }
}
