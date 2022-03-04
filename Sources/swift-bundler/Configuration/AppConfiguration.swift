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
  func withExpressionsEvaluated(_ evaluator: ExpressionEvaluator) throws -> AppConfiguration {
    // Strings fields to evaluate
    let keyPaths: [WritableKeyPath<AppConfiguration, String>] = [\.version]
    
    // Evaluate the expression at each field that supports expressions
    var config = self
    for keyPath in keyPaths {
      config[keyPath: keyPath] = try evaluator.evaluateExpression(config[keyPath: keyPath])
    }
    
    // Evaluate expressions in the plist entry values
    config.extraPlistEntries = try config.extraPlistEntries.mapValues(evaluator.evaluateExpression(_:))
    
    return config
  }
}
