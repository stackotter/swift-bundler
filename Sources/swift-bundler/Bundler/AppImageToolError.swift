import Foundation

/// An error returned by ``AppImageTool``.
enum AppImageToolError: LocalizedError {
  case failedToRunAppImageTool(command: String, Error)

  var errorDescription: String? {
    switch self {
      case .failedToRunAppImageTool(_, let error):
        return "Failed to run appimagetool: \(error)"
    }
  }
}
