import Foundation

/// An error returned by ``Xcodebuild``.
enum XcodebuildError: LocalizedError {
  case failedToRunXcodebuild(command: String, ProcessError)
  case unsupportedPlatform(_ platform: Platform)
  case failedToMoveInterferingScheme(URL, destination: URL, Error)

  var errorDescription: String? {
    switch self {
      case .failedToRunXcodebuild(let command, let processError):
        return "Failed to run '\(command)': \(processError.localizedDescription)"
      case .unsupportedPlatform(let platform):
        return """
          The xcodebuild backend doesn't support '\(platform.name)'. Only \
          Apple platforms are supported.
          """
      case .failedToMoveInterferingScheme(let scheme, _, _):
        let relativePath = scheme.path(relativeTo: URL(fileURLWithPath: "."))
        return """
          Failed to temporarily relocate Xcode scheme at '\(relativePath)' which \
          would otherwise interfere with the build process. Move it manually \
          and try again.
          """
    }
  }
}
