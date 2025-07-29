import Foundation
import ErrorKit

extension MSIBundler {
  typealias Error = RichError<ErrorMessage>

  enum ErrorMessage: Throwable {
    case failedToWriteWXSFile
    case failedToSerializeWXSFile
    case failedToEnumerateBundle
    case failedToRunWiX

    var userFriendlyMessage: String {
      switch self {
        case .failedToWriteWXSFile:
          return "Failed to write WiX configuration file"
        case .failedToSerializeWXSFile:
          return "Failed to serialize WiX configuration file"
        case .failedToEnumerateBundle:
          return "Failed to enumerate generic app bundle structure"
        case .failedToRunWiX:
          return "Failed to run WiX MSI builder"
      }
    }
  }
}
