import Foundation

enum AppConfigurationError: LocalizedError {
  case invalidValueExpression(key: String, value: String, ExpressionEvaluatorError)
  case invalidPlistEntryValueExpression(key: String, value: String, ExpressionEvaluatorError)
}

struct AppConfiguration {
  var target: String
  var version: String
  var category: String
  var bundleIdentifier: String
  var minMacOSVersion: String
  var extraPlistEntries: [String: String]
  
  static var `default` = AppConfiguration(
    target: "ExampleApp",
    version: "0.1.0",
    category: "public.app-category.example",
    bundleIdentifier: "com.example.example",
    minMacOSVersion: "10.13",
    extraPlistEntries: [:])
  
  /// Evaluates the value expressions for each field that supports expressions.
  ///
  /// The currently supported fields are:
  /// - `version`
  /// - `extraPlistEntries`
  ///
  /// - Parameter evaluator: The evaluator to evaluate expressions with.
  /// - Returns: The configuration with all expressions evaluated.
  /// - Throws: If any of the expressions are invalid, an error is thrown.
  func withExpressionsEvaluated(_ evaluator: ExpressionEvaluator) -> Result<AppConfiguration, AppConfigurationError> {
    // Strings fields to evaluate
    let keyPaths: [WritableKeyPath<AppConfiguration, String>] = [\.version]
    
    // Evaluate the expression at each field that supports expressions
    var config = self
    for keyPath in keyPaths {
      let result = evaluator.evaluateExpression(config[keyPath: keyPath])
      switch result {
        case let .success(value):
          config[keyPath: keyPath] = value
        case let .failure(error):
          return .failure(
            .invalidValueExpression(
              key: Mirror(reflecting: keyPath).description,
              value: config[keyPath: keyPath],
              error
            ))
      }
    }
    
    // Evaluate expressions in the plist entry values
    for (key, value) in config.extraPlistEntries {
      let result = evaluator.evaluateExpression(value)
      switch result {
        case let .success(evaluatedValue):
          config.extraPlistEntries[key] = evaluatedValue
        case let .failure(error):
          return .failure(.invalidPlistEntryValueExpression(key: key, value: value, error))
      }
    }
    
    return .success(config)
  }
}
