import Foundation

/// An error returned by ``XcodeSupportGenerator``.
enum XcodeSupportGeneratorError: LocalizedError {
  case failedToGetApplicationSupportDirectory(Error)
  case applicationSupportDirectoryCannotContainSingleQuote(URL)
  case failedToCreateSchemesDirectory(URL, Error)
  case failedToWriteToAppScheme(app: String, Error)
  case failedToCreateOutputBundle(Error)

  var errorDescription: String? {
    switch self {
      case .failedToGetApplicationSupportDirectory:
        return "Failed to get application support directory"
      case .applicationSupportDirectoryCannotContainSingleQuote(let directory):
        return "The build application support directory (\"\(directory.relativePath)\") must not contain single quotes"
      case .failedToCreateSchemesDirectory(let directory, _):
        return "Failed to create schemes directory at '\(directory.relativePath)'"
      case .failedToWriteToAppScheme(let app, _):
        return "Failed to write app scheme for '\(app)' to output file"
      case .failedToCreateOutputBundle:
        return "Failed to create output bundle location for Xcode builds"
    }
  }
}
