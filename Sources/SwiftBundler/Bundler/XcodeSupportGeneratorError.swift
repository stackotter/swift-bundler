import Foundation
import ErrorKit

extension XcodeSupportGenerator {
  typealias Error = RichError<ErrorMessage>

  /// An error message related to ``XcodeSupportGenerator``.
  enum ErrorMessage: Throwable {
    case applicationSupportDirectoryCannotContainSingleQuote(URL)
    case failedToCreateSchemesDirectory(URL)
    case failedToWriteToAppScheme(app: String)
    case failedToCreateOutputBundle

    var userFriendlyMessage: String {
      switch self {
        case .applicationSupportDirectoryCannotContainSingleQuote(let directory):
          return
            "The build application support directory (\"\(directory.relativePath)\") must not contain single quotes"
        case .failedToCreateSchemesDirectory(let directory):
          return "Failed to create schemes directory at '\(directory.relativePath)'"
        case .failedToWriteToAppScheme(let app):
          return "Failed to write app scheme for '\(app)' to output file"
        case .failedToCreateOutputBundle:
          return "Failed to create output bundle location for Xcode builds"
      }
    }
  }
}
