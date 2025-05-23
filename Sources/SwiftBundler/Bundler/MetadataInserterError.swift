import Foundation

/// An error returned by ``MetadataInserter``.
enum MetadataInserterError: LocalizedError {
  case failedToEncodeMetadata(any Error)
  case failedToWriteMetadataCodeFile(any Error)
  case failedToCompileMetadataCodeFile(ProcessError)
  case failedToGetSDKPath(SwiftPackageManagerError)
  case failedToCreateStaticLibrary(ProcessError)
  case failedToCreateUniversalStaticLibrary(ProcessError)

  var errorDescription: String? {
    switch self {
      case .failedToEncodeMetadata(let error):
        return "Failed to encode metadata: \(error.localizedDescription)"
      case .failedToWriteMetadataCodeFile(let error):
        return "Failed to write metadata code file: \(error.localizedDescription)"
      case .failedToCompileMetadataCodeFile(let error):
        return "Failed to compile metadata code file: \(error.localizedDescription)"
      case .failedToGetSDKPath(let error):
        return "Failed to get SDK path for target platform: \(error.localizedDescription)"
      case .failedToCreateStaticLibrary(let error):
        return "Failed to create static library: \(error.localizedDescription)"
      case .failedToCreateUniversalStaticLibrary(let error):
        return "Failed to create universal static library: \(error.localizedDescription)"
    }
  }
}
