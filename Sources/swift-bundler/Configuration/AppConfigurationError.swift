import Foundation

/// An error related to the configuration of a specific app.
enum AppConfigurationError: LocalizedError {
  case invalidValueExpression(key: String, value: String, ExpressionEvaluatorError)
  case invalidPlistEntryValueExpression(key: String, value: String, ExpressionEvaluatorError)

  var errorDescription: String? {
    switch self {
      case .invalidValueExpression(_, _, let expressionEvaluatorError):
        return expressionEvaluatorError.localizedDescription
      case .invalidPlistEntryValueExpression(_, _, let expressionEvaluatorError):
        return expressionEvaluatorError.localizedDescription
    }
  }
}
