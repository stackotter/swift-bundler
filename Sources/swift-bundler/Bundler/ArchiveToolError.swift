import Foundation

/// An error returned by ``ArchiveTool``.
enum ArchiveToolError: LocalizedError {
  case failedToCreateTarGz(directory: URL, outputFile: URL, ProcessError)

  var errorDescription: String? {
    switch self {
      case .failedToCreateTarGz(let directory, let outputFile, _):
        return """
          Failed to create .tar.gz archive of '\(directory.relativePath)' at \
          '\(outputFile.relativePath)'
          """
    }
  }
}
