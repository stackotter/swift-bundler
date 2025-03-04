import Foundation

enum SystemError: LocalizedError {
  case failedToGetApplicationSupportDirectory(Error)
  case failedToCreateApplicationSupportDirectory(Error)

  var errorDescription: String? {
    switch self {
      case .failedToGetApplicationSupportDirectory:
        return "Failed to get application support directory"
      case .failedToCreateApplicationSupportDirectory:
        return "Failed to create application support directory"
    }
  }
}
