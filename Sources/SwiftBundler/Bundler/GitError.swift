import Foundation
import ErrorKit

extension Git {
  typealias Error = RichError<ErrorMessage>

  enum ErrorMessage: Throwable {
    case failedToCloneRepository(_ remote: URL, destination: URL)
    case failedToGetRemoteURL(_ repository: URL, remote: String)
    case invalidRemoteURL(String)

    var userFriendlyMessage: String {
      switch self {
        case .failedToCloneRepository(let remote, let destination):
          let destinationPath = destination.path(relativeTo: .currentDirectory)
          return "Failed to clone repository '\(remote)' to '\(destinationPath)'"
        case .failedToGetRemoteURL(let repository, let remote):
          let repositoryPath = repository.path(relativeTo: .currentDirectory)
          return """
            Failed to get URL of remote '\(remote)' in local repository \
            '\(repositoryPath)'
            """
        case .invalidRemoteURL(let url):
          return "Invalid remote URL '\(url)'"
      }
    }
  }
}
