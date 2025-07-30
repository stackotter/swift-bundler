import Foundation
import ErrorKit

extension MetadataInserter {
  typealias Error = RichError<ErrorMessage>

  /// An error related to ``MetadataInserter``.
  enum ErrorMessage: Throwable {
    case failedToEncodeMetadata
    case failedToWriteMetadataCodeFile
    case failedToCompileMetadataCodeFile
    case failedToGetSDKPath
    case failedToCreateStaticLibrary
    case failedToCreateUniversalStaticLibrary

    var userFriendlyMessage: String {
      switch self {
        case .failedToEncodeMetadata:
          return "Failed to encode metadata"
        case .failedToWriteMetadataCodeFile:
          return "Failed to write metadata code file"
        case .failedToCompileMetadataCodeFile:
          return "Failed to compile metadata code file"
        case .failedToGetSDKPath:
          return "Failed to get SDK path for target platform"
        case .failedToCreateStaticLibrary:
          return "Failed to create static library"
        case .failedToCreateUniversalStaticLibrary:
          return "Failed to create universal static library"
      }
    }
  }
}
