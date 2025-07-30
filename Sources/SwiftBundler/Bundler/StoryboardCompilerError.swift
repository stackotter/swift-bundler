import Foundation
import ErrorKit

extension StoryboardCompiler {
  typealias Error = RichError<ErrorMessage>

  /// An error message related to ``StoryboardCompiler``.
  enum ErrorMessage: Throwable {
    case failedToEnumerateStoryboards(URL)
    case failedToCreateOutputDirectory(URL)
    case failedToRunIBTool(storyboard: URL)
    case failedToDeleteStoryboard(URL)

    var userFriendlyMessage: String {
      switch self {
        case .failedToEnumerateStoryboards(let directory):
          return "Failed to enumerate storyboards in '\(directory.relativePath)'"
        case .failedToCreateOutputDirectory(let directory):
          return "Failed to create output directory at '\(directory.relativePath)'"
        case .failedToRunIBTool(let storyboard):
          return "Failed to run IB tool on '\(storyboard)'"
        case .failedToDeleteStoryboard(let file):
          return "Failed to delete storyboard at '\(file.relativePath)' after compilation"
      }
    }
  }
}
