import Foundation

/// An error returned by ``StoryboardCompiler``.
enum StoryboardCompilerError: LocalizedError {
  case failedToEnumerateStoryboards(URL, Error)
  case failedToCreateOutputDirectory(URL, Error)
  case failedToRunIBTool(storyboard: URL, ProcessError)
  case failedToDeleteStoryboard(URL, Error)

  var errorDescription: String? {
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
