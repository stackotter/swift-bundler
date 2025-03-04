import Foundation

/// An error returned by ``RPMBundler``.
enum RPMBundlerError: LocalizedError {
  case failedToRunGenericBundler(GenericLinuxBundlerError)
  case failedToCreateRPMBuildDirectory(directory: URL, any Error)
  case failedToArchiveSources(ArchiveToolError)
  case failedToWriteSpecFile(URL, any Error)
  case failedToRunRPMBuildTool(_ command: String, ProcessError)
  case failedToCopyGenericBundle(source: URL, destination: URL, any Error)
  case failedToEnumerateRPMs(_ directory: URL)
  case failedToFindProducedRPM(_ directory: URL)
  case failedToCopyRPMToOutputDirectory(source: URL, destination: URL, any Error)

  var errorDescription: String? {
    switch self {
      case .failedToRunGenericBundler(let error):
        return error.localizedDescription
      case .failedToCreateRPMBuildDirectory(let directory, _):
        return "Failed to create '\(directory.relativePath)'"
      case .failedToArchiveSources(let error):
        return error.localizedDescription
      case .failedToWriteSpecFile(let file, _):
        return "Failed to write spec file at '\(file.relativePath)'"
      case .failedToRunRPMBuildTool(let command, let error):
        return """
          Failed to run '\(command)' (rerun with -v to see invocation): \
          \(error.localizedDescription)
          """
      case .failedToCopyGenericBundle(let source, let destination, _):
        return """
          Failed to copy generic linux bundle from '\(source.relativePath)' to \
          '\(destination.relativePath)'
          """
      case .failedToEnumerateRPMs(let directory):
        return "Failed to enumerate RPMs in '\(directory.relativePath)'"
      case .failedToFindProducedRPM(let directory):
        return "Failed to find produced RPM in '\(directory.relativePath)'"
      case .failedToCopyRPMToOutputDirectory(let source, let destination, _):
        return """
          Failed to copy '\(source.relativePath)' to \
          '\(destination.relativePath)'
          """
    }
  }
}
