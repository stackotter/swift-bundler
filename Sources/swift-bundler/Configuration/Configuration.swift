import Foundation
import TOMLKit
import Overture

enum ConfigurationError: LocalizedError {
  case failedToLoadConfiguration(Error)
  case invalidAppName(String)
  case multipleAppsAndNoneSpecified
}

struct Configuration {
  /// The configuration specific to each app.
  var apps: [String: AppConfiguration]
  
  /// Gets the configuration for the specified app. If no app is specified and there is only one app, that app is used.
  /// - Parameter name: The name of the app to get.
  /// - Returns: The app configuration.
  /// - Throws: If no app is specified, and there is more than one app, an error is thrown.
  func getAppConfiguration(_ name: String?) throws -> AppConfiguration {
    if let name = name {
      guard let selected = apps[name] else {
        throw ConfigurationError.invalidAppName(name)
      }
      return selected
    } else if let first = apps.first, apps.count == 1 {
      return first.value
    } else {
      throw ConfigurationError.multipleAppsAndNoneSpecified
    }
  }
  
  /// Evaluates the expressions in all configuration field values that support expressions.
  /// - Parameter context: The evaluator context to use.
  /// - Returns: The evaluated configuration.
  /// - Throws: If any of the expressions are invalid, an error is thrown.
  func withExpressionsEvaluated(_ context: ExpressionEvaluator.Context) throws -> Configuration {
    let evaluator = ExpressionEvaluator(context: context)
    let evaluateAppConfiguration = flip(AppConfiguration.withExpressionsEvaluated)(evaluator)
    var config = self
    config.apps = try config.apps.mapValues { value in
      try evaluateAppConfiguration(value)
    }
    return config
  }
  
  /// Loads configuration from the `Bundler.toml` file in the given directory.
  /// - Parameters:
  ///   - packageDirectory: The directory containing the configuration file.
  ///   - evaluatorContext: Used to evaluate configuration values that support expressions.
  /// - Returns: The configuration.
  static func load(fromDirectory packageDirectory: URL, evaluatorContext: ExpressionEvaluator.Context) throws -> Configuration {
    do {
      let configurationFile = packageDirectory.appendingPathComponent("Bundler.toml")
      let dto = try TOMLDecoder().decode(
        ConfigurationDTO.self,
        from: try String(contentsOf: configurationFile))
      let configuration = Configuration(dto)
      return try configuration.withExpressionsEvaluated(evaluatorContext)
    } catch {
      throw ConfigurationError.failedToLoadConfiguration(error)
    }
  }
}
