import Foundation
import ErrorKit

extension VariableEvaluator {
  typealias Error = RichError<ErrorMessage>

  /// An error message related to ``VariableEvaluator``.
  enum ErrorMessage: Throwable {
    case unmatchedBrackets(String)
    case unknownVariable(String)
    case failedToEvaluateCommitHash(directory: URL)
    case failedToEvaluateRevisionNumber(directory: URL)
    case customEvaluatorFailedToEvaluateVariable(String)
    case packageDirectoryRequiredToEvaluateCommitHash
    case packageDirectoryRequiredToEvaluateRevisionNumber

    var userFriendlyMessage: String {
      switch self {
        case .unmatchedBrackets(let string):
          return "Unmatched brackets in '\(string)'"
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
        case .customEvaluatorFailedToEvaluateVariable(let variable):
          return "Custom evaluator failed to evaluate variable '\(variable)'"
        case .packageDirectoryRequiredToEvaluateCommitHash:
          return "Failed to evaluate COMMIT_HASH. Context missing package directory"
        case .packageDirectoryRequiredToEvaluateRevisionNumber:
          return "Failed to evaluate REVISION_NUMBER. Context missing package directory"
      }
    }
  }
}
