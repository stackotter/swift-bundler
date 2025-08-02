import Foundation
import ErrorKit

extension ProjectConfiguration {
  typealias Error = RichError<ErrorMessage>

  /// An error message related to ``ProjectConfiguration``.
  enum ErrorMessage: Throwable {
    case invalidGitURL(String)
    case gitSourceMissingRevision(URL, field: CodingPath)
    case localSourceMustNotSpecifyRevision(_ path: String)
    case gitSourceMissingAPIRequirement(_ url: URL)
    case defaultSourceMissingAPIRequirement

    var userFriendlyMessage: String {
      switch self {
        case .invalidGitURL(let url):
          return "'\(url)' is not a valid URL"
        case .gitSourceMissingRevision(let gitURL, let field):
          return
            """
            Git source '\(gitURL.absoluteString)' requires a revision. Provide
            the '\(field)' field.
            """
        case .localSourceMustNotSpecifyRevision(let path):
          return "'api' field is redundant when local builder API is used ('local(\(path))')"
        case .gitSourceMissingAPIRequirement:
          return "Builder API sourced from git missing API requirement (provide the 'api' field)"
        case .defaultSourceMissingAPIRequirement:
          return "Default Builder API missing API requirement (provide the 'api' field)"
      }
    }
  }
}
