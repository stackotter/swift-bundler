import Foundation
import ErrorKit

extension AppImageBundler {
  typealias Error = RichError<ErrorMessage>

  /// An error message related to ``AppImageBundler``.
  enum ErrorMessage: Throwable {
    case failedToCreateSymlink(source: URL, relativeDestination: String)
    case failedToBundleAppDir
    case failedToRenameGenericBundle(source: URL, destination: URL)
    case failedToCopyDesktopFile(source: URL, destination: URL)

    var userFriendlyMessage: String {
      switch self {
        case .failedToCreateSymlink(let source, let destination):
          return """
            Failed to create symlink from '\(source.relativePath)' to relative \
            path '\(destination)'
            """
        case .failedToBundleAppDir:
          return "Failed to convert AppDir to AppImage"
        case .failedToRenameGenericBundle(let source, let destination):
          return """
            Failed to move generic bundle from '\(source.relativePath)' \
            to '\(destination.relativePath)'
            """
        case .failedToCopyDesktopFile(let source, let destination):
          return """
            Failed to copy '\(source.relativePath)' to '\(destination.relativePath)'
            """
      }
    }
  }
}
