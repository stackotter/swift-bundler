import Foundation

extension GenericWindowsBundler {
  enum Error: LocalizedError {
    case failedToCreateDirectory(URL, Swift.Error)
    case failedToCopyExecutableDependency(
      name: String,
      source: URL,
      destination: URL,
      Swift.Error
    )
    case failedToInsertMetadata(MetadataInserterError)
    case failedToEnumerateResourceBundles(URL, Swift.Error)
    case failedToCopyResourceBundle(source: URL, destination: URL, Swift.Error)
    case failedToCopyExecutable(source: URL, destination: URL, Swift.Error)
    case failedToParseDumpbinOutput(output: String, message: String)
    case failedToResolveDLLName(String)
    case failedToEnumerateDynamicDependencies(ProcessError)
    case failedToCopyDLL(source: URL, destination: URL, Swift.Error)
  }
}
