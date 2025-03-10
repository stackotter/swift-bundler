import Foundation

/// An error returned by ``VariableEvaluator``.
enum VariableEvaluatorError: LocalizedError {
  case unmatchedBrackets(String, Error)
  case unknownVariable(String)
  case failedToEvaluateCommitHash(directory: URL)
  case failedToEvaluateRevisionNumber(directory: URL)
  case customEvaluatorFailedToEvaluateVariable(String, Error)
  case packageDirectoryRequiredToEvaluateCommitHash
  case packageDirectoryRequiredToEvaluateRevisionNumber

  var errorDescription: String? {
    switch self {
      case .unmatchedBrackets(let string, let error):
        return "Unmatched brackets in '\(string)'\n\(error)"
      case .unknownVariable(let variable):
        return "Found unknown variable '\(variable)'"
      case .failedToEvaluateCommitHash(let directory):
        return """
          Failed to evaluate the 'COMMIT_HASH' variable. Ensure that \
          '\(directory.relativePath)' is a git repository and that git is \
          installed and on your PATH.
          """
      case .failedToEvaluateRevisionNumber(let directory):
        return """
          Failed to evaluate the 'REVISION_NUMBER' variable. Ensure that \
          '\(directory.relativePath)' is a git repository and that git is \
          installed and on your PATH.
          """
      case .customEvaluatorFailedToEvaluateVariable(let variable, _):
        return "Custom evaluator failed to evaluate variable '\(variable)'"
      case .packageDirectoryRequiredToEvaluateCommitHash:
        return "Failed to evaluate COMMIT_HASH. Context missing package directory"
      case .packageDirectoryRequiredToEvaluateRevisionNumber:
        return "Failed to evaluate REVISION_NUMBER. Context missing package directory"
    }
  }
}
