import ErrorKit
import Foundation

extension LayeredIconCreator {
  typealias Error = RichError<ErrorMessage>

  /// An error message related to ``LayeredIconCreator``.
  enum ErrorMessage: Throwable {
    case notIconFile(URL)
    case failedToCreateIconDirectory(URL)
    case failedToCopyFile(URL, URL)
    case failedToConvertToICNS
    case failedToRemoveIconDirectory(URL)

    var userFriendlyMessage: String {
      switch self {
        case .notIconFile(let file):
          return "Expected an icon file with .icon extension, but '\(file)' is not an icon file"
        case .failedToCreateIconDirectory(let directory):
          return """
            Failed to create a temporary icon directory at '\(directory.relativePath)'
            """
        case .failedToCopyFile(let from, let to):
          return """
            Failed to copy file from '\(from.relativePath)' to '\(to.relativePath)'
            """
        case .failedToConvertToICNS:
          return "Failed to convert the icon set directory to an 'icns' file"
        case .failedToRemoveIconDirectory(let directory):
          return """
            Failed to remove the temporary icon directory at '\(directory.relativePath)'
            """
      }
    }
  }
}
