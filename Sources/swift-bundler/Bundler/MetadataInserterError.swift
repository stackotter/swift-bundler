import Foundation

/// An error returned by ``MetadataInserter``.
enum MetadataInserterError: LocalizedError {
  case failedToReadExecutableFile(URL, any Error)
  case failedToEncodeMetadata(any Error)
  case failedToWriteExecutableFile(URL, any Error)
}
