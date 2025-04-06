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
    case failedToCopyPDB(source: URL, destination: URL, Swift.Error)

    var errorDescription: String? {
      switch self {
        case .failedToCreateDirectory(let directory, let error):
          return """
            Failed to create directory at \
            '\(directory.path(relativeTo: .currentDirectory))': \
            \(error.localizedDescription)
            """
        case .failedToCopyExecutableDependency(
          let name,
          _,
          _,
          let error
        ):
          return """
            Failed to copy dependency '\(name)' to output bundle: \
            \(error.localizedDescription)
            """
        case .failedToInsertMetadata(let error):
          return """
            Failed to insert metadata into main executable: \
            \(error.localizedDescription)
            """
        case .failedToEnumerateResourceBundles(let directory, let error):
          return """
            Failed to enumerate resource bundles in \
            '\(directory.path(relativeTo: .currentDirectory))': \
            \(error.localizedDescription)
            """
        case .failedToCopyResourceBundle(let source, let destination, let error):
          return """
            Failed to copy resource bundle from \
            '\(source.path(relativeTo: .currentDirectory))' to \
            '\(destination.path(relativeTo: .currentDirectory))': \
            \(error.localizedDescription)
            """
        case .failedToCopyExecutable(let source, let destination, let error):
          return """
            Failed to copy executable from \
            '\(source.path(relativeTo: .currentDirectory))' to \
            '\(destination.path(relativeTo: .currentDirectory))': \
            \(error.localizedDescription)
            """
        case .failedToParseDumpbinOutput(_, let message):
          return "Failed to parse dumpbin output: \(message)"
        case .failedToResolveDLLName(let name):
          return "Failed to resolve path to DLL named '\(name)'"
        case .failedToEnumerateDynamicDependencies(let error):
          return "Failed to run dumpbin: \(error.localizedDescription)"
        case .failedToCopyDLL(let source, let destination, let error):
          return """
            Failed to copy DLL from \
            '\(source.path(relativeTo: .currentDirectory))' to \
            '\(destination.path(relativeTo: .currentDirectory))': \
            \(error.localizedDescription)
            """
        case .failedToCopyPDB(let source, let destination, let error):
          return """
            Failed to copy PDB from \
            '\(source.path(relativeTo: .currentDirectory))' to \
            '\(destination.path(relativeTo: .currentDirectory))': \
            \(error.localizedDescription)
            """
      }
    }
  }
}
