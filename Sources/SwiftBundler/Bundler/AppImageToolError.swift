import Foundation
import ErrorKit

extension AppImageTool {
  typealias Error = RichError<ErrorMessage>

  /// An error message related to ``AppImageTool``.
  enum ErrorMessage: Throwable {
    case failedToRunAppImageTool

    var userFriendlyMessage: String {
      switch self {
        case .failedToRunAppImageTool:
          return "Failed to run appimagetool"
      }
    }
  }
}
