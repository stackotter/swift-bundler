import Foundation
import ErrorKit

extension AppConfiguration {
  typealias Error = RichError<ErrorMessage>

  /// An error meesage related to ``AppConfiguration``.
  enum ErrorMessage: Throwable {
    case failedToLoadInfoPlistEntries(file: URL)
    case invalidRPMRequirement(String)

    var userFriendlyMessage: String {
      switch self {
        case .failedToLoadInfoPlistEntries(let file):
          return "Failed to load '\(file.relativePath)' for appending to app configuration"
        case .invalidRPMRequirement(let requirement):
          return "RPM requirement invalid, contains restricted characters: \(requirement)"
      }
    }
  }
}
