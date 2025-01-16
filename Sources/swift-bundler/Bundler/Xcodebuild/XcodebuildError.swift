import Foundation

/// An error returned by ``Xcodebuild``.
enum XcodebuildError: LocalizedError {
  case failedToRunXcodebuild(command: String, ProcessError)
  case unsupportedPlatform(_ platform: Platform)

  var errorDescription: String? {
    switch self {
      case .failedToRunXcodebuild(let command, let processError):
        return "Failed to run '\(command)': \(processError.localizedDescription)"
      case .unsupportedPlatform(let platform):
        return """
          The xcodebuild backend doesn't support '\(platform.name)'. Only \
          Apple platforms are supported.
          """
    }
  }
}
