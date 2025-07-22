import Foundation
import ErrorKit

/// An error returned by ``AppImageBundler``.
enum AppImageBundlerError: Throwable {
  case failedToCreateSymlink(source: URL, relativeDestination: String, Error)
  case failedToBundleAppDir(AppImageToolError)
  case failedToRunGenericBundler(GenericLinuxBundlerError)
  case failedToRenameGenericBundle(source: URL, destination: URL, Error)
  case failedToCopyDesktopFile(source: URL, destination: URL, Error)

  var userFriendlyMessage: String {
    switch self {
      case .failedToCreateSymlink(let source, let destination, _):
        return """
          Failed to create symlink from '\(source.relativePath)' to relative \
          path '\(destination)'
          """
      case .failedToBundleAppDir(let error):
        return "Failed to convert AppDir to AppImage: \(error)"
      case .failedToRunGenericBundler(let error):
        return error.localizedDescription
      case .failedToRenameGenericBundle(let source, let destination, _):
        return """
          Failed to move generic bundle from '\(source.relativePath)' \
          to '\(destination.relativePath)'
          """
      case .failedToCopyDesktopFile(let source, let destination, _):
        return """
          Failed to copy '\(source.relativePath)' to '\(destination.relativePath)'
          """
    }
  }
}
