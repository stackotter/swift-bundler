import Foundation

/// An error returned by ``XcodeBuildManager``.
enum XcodeBuildManagerError: LocalizedError {
  case failedToRunXcodeBuild(command: String, ProcessError)

  var errorDescription: String? {
    switch self {
      case .failedToRunXcodeBuild(let command, let processError):
        return "Failed to run '\(command)': \(processError.localizedDescription)"
    }
  }
}
