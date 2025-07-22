import Foundation
import ErrorKit

/// An error related to the configuration of a specific app.
enum AppConfigurationError: Throwable {
  case failedToLoadInfoPlistEntries(file: URL, error: PlistError)

  var userFriendlyMessage: String {
    switch self {
      case .failedToLoadInfoPlistEntries(let file, let error):
        return
          "Failed to load '\(file.relativePath)' for appending to app configuration: \(error.localizedDescription)"
    }
  }
}
