import Foundation
import ErrorKit

/// An error returned by ``StoryboardCompiler``.
enum StoryboardCompilerError: Throwable {
  case failedToEnumerateStoryboards(URL, Error)
  case failedToCreateOutputDirectory(URL, Error)
  case failedToRunIBTool(storyboard: URL, Process.Error)
  case failedToDeleteStoryboard(URL, Error)

  var userFriendlyMessage: String {
    switch self {
      case .failedToEnumerateStoryboards(let directory, _):
        return "Failed to enumerate storyboards in '\(directory.relativePath)'"
      case .failedToCreateOutputDirectory(let directory, _):
        return "Failed to create output directory at '\(directory.relativePath)'"
      case .failedToRunIBTool(let storyboard, _):
        return "Failed to run IB tool on '\(storyboard)'"
      case .failedToDeleteStoryboard(let file, _):
        return "Failed to delete storyboard at '\(file.relativePath)' after compilation"
    }
  }
}
