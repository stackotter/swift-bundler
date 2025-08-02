import Foundation
import ErrorKit

extension Xcodebuild {
  typealias Error = RichError<ErrorMessage>

  /// An error message related to ``Xcodebuild``.
  enum ErrorMessage: Throwable {
    case failedToRunXcodebuild(command: String)
    case unsupportedPlatform(_ platform: Platform)
    case failedToMoveInterferingScheme(URL, destination: URL)

    var userFriendlyMessage: String {
      switch self {
        case .failedToRunXcodebuild(let command):
          return "Failed to run '\(command)'"
        case .unsupportedPlatform(let platform):
          return """
            The xcodebuild backend doesn't support '\(platform.name)'. Only \
            Apple platforms are supported.
            """
        case .failedToMoveInterferingScheme(let scheme, _):
          let relativePath = scheme.path(relativeTo: URL(fileURLWithPath: "."))
          return """
            Failed to temporarily relocate Xcode scheme at '\(relativePath)' which \
            would otherwise interfere with the build process. Move it manually \
            and try again.
            """
      }
    }
  }
}
