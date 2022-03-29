import Foundation

/// An error related to the configuration of a specific app.
enum AppConfigurationError: LocalizedError {
  case invalidValueExpression(key: String, value: String, ExpressionEvaluatorError)
  case invalidPlistEntryValueExpression(key: String, value: String, ExpressionEvaluatorError)
}

/// The configuration of an app.
struct AppConfiguration {
  /// The name of the executable product.
  var product: String
  /// The app's current version.
  var version: String
  /// The app's category. See [Apple's documentation](https://developer.apple.com/app-store/categories/) for more details.
  var category: String
  /// The app's bundle identifier (e.g. `com.example.ExampleApp`).
  var bundleIdentifier: String
  /// The minimum macOS version that the app can run on.
  var minimumMacOSVersion: String
  /// A dictionary containing extra entries to add to the app's `Info.plist` file. The values can contain expressions (see ``ExpressionEvaluator`` for details).
  var extraPlistEntries: [String: String]
  
  /// The default app configuration.
  static var `default` = AppConfiguration(
    product: "ExampleApp",
    version: "0.1.0",
    category: "public.app-category.example",
    bundleIdentifier: "com.example.example",
    minimumMacOSVersion: "10.13",
    extraPlistEntries: [:])
  
  /// Evaluates the value expressions for each field that supports expressions.
  ///
  /// The currently supported fields are:
  /// - `version`
  /// - `extraPlistEntries`
  ///
  /// - Parameter evaluator: The evaluator to evaluate expressions with.
  /// - Returns: The configuration with all expressions evaluated. If any of the expressions are invalid, a failure is returned.
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
