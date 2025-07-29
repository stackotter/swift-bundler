import Foundation
import ErrorKit

extension ArchiveTool {
  typealias Error = RichError<ErrorMessage>

  /// An error related to ``ArchiveTool``.
  enum ErrorMessage: Throwable {
    case failedToCreateTarGz(directory: URL, outputFile: URL)

    var userFriendlyMessage: String {
      switch self {
        case .failedToCreateTarGz(let directory, let outputFile):
          return """
            Failed to create .tar.gz archive of '\(directory.relativePath)' at \
            '\(outputFile.relativePath)'
            """
      }
    }
  }
}
