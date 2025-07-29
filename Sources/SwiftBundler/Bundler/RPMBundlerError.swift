import Foundation
import ErrorKit

extension RPMBundler {
  typealias Error = RichError<ErrorMessage>

  /// An error message related to ``RPMBundler``.
  enum ErrorMessage: Throwable {
    case failedToCreateRPMBuildDirectory(directory: URL)
    case failedToWriteSpecFile(URL)
    case failedToRunRPMBuildTool(_ command: String)
    case failedToCopyGenericBundle(source: URL, destination: URL)
    case failedToEnumerateRPMs(_ directory: URL)
    case failedToFindProducedRPM(_ directory: URL)
    case failedToCopyRPMToOutputDirectory(source: URL, destination: URL)

    var userFriendlyMessage: String {
      switch self {
        case .failedToCreateRPMBuildDirectory(let directory):
          return "Failed to create '\(directory.relativePath)'"
        case .failedToWriteSpecFile(let file):
          return "Failed to write spec file at '\(file.relativePath)'"
        case .failedToRunRPMBuildTool(let command):
          return "Failed to run '\(command)' (rerun with -v to see invocation)"
        case .failedToCopyGenericBundle(let source, let destination):
          return """
            Failed to copy generic linux bundle from '\(source.relativePath)' to \
            '\(destination.relativePath)'
            """
        case .failedToEnumerateRPMs(let directory):
          return "Failed to enumerate RPMs in '\(directory.relativePath)'"
        case .failedToFindProducedRPM(let directory):
          return "Failed to find produced RPM in '\(directory.relativePath)'"
        case .failedToCopyRPMToOutputDirectory(let source, let destination):
          return """
            Failed to copy '\(source.relativePath)' to \
            '\(destination.relativePath)'
            """
      }
    }
  }
}
