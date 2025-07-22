import Foundation
import ErrorKit

/// An error returned by ``ArchiveTool``.
enum ArchiveToolError: Throwable {
  case failedToCreateTarGz(directory: URL, outputFile: URL, Process.Error)

  var userFriendlyMessage: String {
    switch self {
      case .failedToCreateTarGz(let directory, let outputFile, _):
        return """
          Failed to create .tar.gz archive of '\(directory.relativePath)' at \
          '\(outputFile.relativePath)'
          """
    }
  }
}
