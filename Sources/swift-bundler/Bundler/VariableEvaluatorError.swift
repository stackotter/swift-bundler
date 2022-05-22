import Foundation

/// An error returned by ``VariableEvaluator``.
enum VariableEvaluatorError: LocalizedError {
  case unmatchedBrackets(String, Error)
  case unknownVariable(String)
  case failedToEvaluateCommitHash(directory: URL)
  case customEvaluatorFailedToEvaluateVariable(String, Error)
  case packageDirectoryRequiredToEvaluateCommitHash

  var errorDescription: String? {
    switch self {
      case .unmatchedBrackets(let string, let error):
        return "Unmatched brackets in '\(string)'\n\(error)"
      case .unknownVariable(let variable):
        return "Found unknown variable '\(variable)'"
      case .failedToEvaluateCommitHash(let directory):
        return "Failed to evaluate the 'COMMIT_HASH' variable. Ensure that '\(directory.relativePath)' is a git repository and"
             + " that git is installed at '/usr/bin/git'."
      case .customEvaluatorFailedToEvaluateVariable(let variable, _):
        return "Custom evaluator failed to evaluate variable '\(variable)'"
      case .packageDirectoryRequiredToEvaluateCommitHash:
        return "Failed to evaluate commit hash. Context missing package directory"
    }
  }
}
