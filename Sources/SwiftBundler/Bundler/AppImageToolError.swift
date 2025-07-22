import Foundation
import ErrorKit

/// An error returned by ``AppImageTool``.
enum AppImageToolError: Throwable {
  case failedToRunAppImageTool(command: String, Process.Error)

  var userFriendlyMessage: String {
    switch self {
      case .failedToRunAppImageTool(_, let error):
        return "Failed to run appimagetool: \(error)"
    }
  }
}
