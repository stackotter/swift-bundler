import Foundation

/// The configuration for an app.
struct AppConfiguration: Codable {
  /// The name of the executable product.
  var product: String
  /// The app's current version.
  var version: String
  // swiftlint:disable:next line_length
  /// The app's category. See [Apple's documentation](https://developer.apple.com/documentation/bundleresources/information_property_list/lsapplicationcategorytype) for more details.
  var category: String?
  /// The app's bundle identifier (e.g. `com.example.ExampleApp`).
  var bundleIdentifier: String?
  /// The minimum macOS version that the app can run on.
  var minimumMacOSVersion: String?
  /// The minimum iOS version that the app can run on.
  var minimumIOSVersion: String?
  /// The path to the app's icon.
  var icon: String?
  /// A dictionary containing extra entries to add to the app's `Info.plist` file.
  ///
  /// The values can contain variable substitutions (see ``ExpressionEvaluator`` for details).
  var extraPlistEntries: [String: String]?

  private enum CodingKeys: String, CodingKey {
    case product
    case version
    case category
    case bundleIdentifier = "bundle_identifier"
    case minimumMacOSVersion = "minimum_macos_version"
    case minimumIOSVersion = "minimum_ios_version"
    case icon
    case extraPlistEntries = "extra_plist_entries"
  }

  /// Evaluates the value expressions for each field that supports expressions.
  ///
  /// The currently supported fields are:
  /// - `extraPlistEntries`
  ///
  /// - Parameter evaluator: The evaluator to evaluate expressions with.
  /// - Returns: The configuration with all expressions evaluated. If any of the expressions are invalid, a failure is returned.
  func withExpressionsEvaluated(_ evaluator: ExpressionEvaluator) -> Result<AppConfiguration, AppConfigurationError> {
    var config = self
    var evaluator = evaluator

    // Evaluate expressions in the plist entry values
    if var extraPlistEntries = config.extraPlistEntries {
      for (key, value) in extraPlistEntries {
        let result = evaluator.evaluateExpression(value)
        switch result {
          case let .success(evaluatedValue):
            extraPlistEntries[key] = evaluatedValue
          case let .failure(error):
            return .failure(.invalidPlistEntryValueExpression(key: key, value: value, error))
        }
      }
      config.extraPlistEntries = extraPlistEntries
    }

    return .success(config)
  }
}
