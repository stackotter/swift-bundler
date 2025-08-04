import Foundation
import ErrorKit

extension System {
  typealias Error = RichError<ErrorMessage>

  enum ErrorMessage: Throwable {
    case failedToGetApplicationSupportDirectory
    case failedToCreateApplicationSupportDirectory

    var userFriendlyMessage: String {
      switch self {
        case .failedToGetApplicationSupportDirectory:
          return "Failed to get application support directory"
        case .failedToCreateApplicationSupportDirectory:
          return "Failed to create application support directory"
      }
    }
  }
}
