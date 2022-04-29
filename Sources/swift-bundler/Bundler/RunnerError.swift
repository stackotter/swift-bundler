import Foundation

/// An error returned by ``Runner``.
enum RunnerError: LocalizedError {
  case failedToRunExecutable(ProcessError)
}
