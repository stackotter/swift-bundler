import Foundation
import ErrorKit

extension PatchElfTool {
  typealias Error = RichError<ErrorMessage>

  /// An error message related to ``PatchElfTool``.
  enum ErrorMessage: Throwable {
    case patchelfNotFound
    case failedToSetRunpath(elfFile: URL)

    var userFriendlyMessage: String {
      switch self {
        case .patchelfNotFound:
          return """
            Command 'patchelf' not found, but required by selected bundler. \
            Please install it and try again.
            """
        case .failedToSetRunpath(let elfFile):
          return "Failed to set runpath of '\(elfFile.path)'"
      }
    }
  }
}
