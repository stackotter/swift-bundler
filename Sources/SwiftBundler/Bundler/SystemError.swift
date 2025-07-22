import Foundation
import ErrorKit

enum SystemError: Throwable {
  case failedToGetApplicationSupportDirectory(Error)
  case failedToCreateApplicationSupportDirectory(Error)

  var userFriendlyMessage: String {
    switch self {
      case .failedToGetApplicationSupportDirectory:
        return "Failed to get application support directory"
      case .failedToCreateApplicationSupportDirectory:
        return "Failed to create application support directory"
    }
  }
}
