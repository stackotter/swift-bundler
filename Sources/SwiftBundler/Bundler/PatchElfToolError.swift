import Foundation
import ErrorKit

/// An error thrown by ``PatchElfTool``.
enum PatchElfToolError: Throwable {
  case patchelfNotFound(Process.Error)
  case failedToSetRunpath(elfFile: URL, Process.Error)

  var userFriendlyMessage: String {
    switch self {
      case .patchelfNotFound:
        return """
          Command 'patchelf' not found, but required by selected bundler. \
          Please install it and try again
          """
      case .failedToSetRunpath(let elfFile, let error):
        return """
          Failed to set runpath of '\(elfFile.path)': \(error.localizedDescription)
          """
    }
  }
}
