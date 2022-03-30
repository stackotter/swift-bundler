import Foundation

/// An error returned by ``ExpressionEvaluator``.
enum ExpressionEvaluatorError: LocalizedError {
  case unknownVariable(String)
  case unmatchedBraces(String, Error)
  case failedToEvaluateExpressionVariable(message: String)
  
  var errorDescription: String? {
    switch self {
      case .unknownVariable(let variable):
        return "Unknown variable '\(variable)'"
      case .unmatchedBraces(let expression, _):
        return "Unmatched brace in '\(expression)'"
      case .failedToEvaluateExpressionVariable(let message):
        return message
    }
  }
}
