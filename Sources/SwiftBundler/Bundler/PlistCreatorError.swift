import Foundation
import ErrorKit

extension PlistCreator {
  typealias Error = RichError<ErrorMessage>

  /// An error message related to ``PlistCreator``.
  enum ErrorMessage: Throwable {
    case failedToWriteAppInfoPlist(file: URL)
    case failedToWriteResourceBundleInfoPlist(bundle: String, file: URL)
    case serializationFailed

    var userFriendlyMessage: String {
      switch self {
        case .failedToWriteAppInfoPlist(let file):
          return "Failed to write to the app's 'Info.plist' at '\(file.relativePath)'"
        case .failedToWriteResourceBundleInfoPlist(let bundle, let file):
          return
            "Failed to write to the '\(bundle)' resource bundle's 'Info.plist' at '\(file.relativePath)'"
        case .serializationFailed:
          return "Failed to serialize a plist dictionary"
      }
    }
  }
}
