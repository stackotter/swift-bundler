import Foundation

/// An error returned by ``PlistCreator``.
enum PlistCreatorError: LocalizedError {
  case failedToWriteAppInfoPlist(file: URL, Error)
  case failedToWriteResourceBundleInfoPlist(bundle: String, file: URL, Error)
  case serializationFailed(Error)
  
  var errorDescription: String? {
    switch self {
      case .failedToWriteAppInfoPlist(let file, _):
        return "Failed to write to the app's 'Info.plist' at '\(file.relativePath)'"
      case .failedToWriteResourceBundleInfoPlist(let bundle, let file, _):
        return "Failed to write to the '\(bundle)' resource bundle's 'Info.plist' at '\(file.relativePath)'"
      case .serializationFailed:
        return "Failed to serialize a plist dictionary"
    }
  }
}
