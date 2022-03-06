import Foundation
import TOMLKit
import Overture

enum ConfigurationError: LocalizedError {
  case invalidAppName(String)
  case multipleAppsAndNoneSpecified
  case failedToEvaluateExpressions(app: String, AppConfigurationError)
  case failedToReadConfigurationFile(Error)
  case failedToDeserializeConfiguration(Error)
}

struct Configuration {
  /// The configuration specific to each app.
  var apps: [String: AppConfiguration]
  
  /// Gets the configuration for the specified app. If no app is specified and there is only one app, that app is used.
  /// - Parameter name: The name of the app to get.
  /// - Returns: The app configuration.
  /// - Throws: If no app is specified, and there is more than one app, an error is thrown.
  func getAppConfiguration(_ name: String?) -> Result<AppConfiguration, ConfigurationError> {
    if let name = name {
      guard let selected = apps[name] else {
        return .failure(.invalidAppName(name))
      }
      return .success(selected)
    } else if let first = apps.first, apps.count == 1 {
      return .success(first.value)
    } else {
      return .failure(.multipleAppsAndNoneSpecified)
    }
  }
  
  /// Evaluates the expressions in all configuration field values that support expressions.
  /// - Parameter context: The evaluator context to use.
  /// - Returns: The evaluated configuration.
  /// - Throws: If any of the expressions are invalid, an error is thrown.
  func withExpressionsEvaluated(_ context: ExpressionEvaluator.Context) -> Result<Configuration, ConfigurationError> {
    let evaluator = ExpressionEvaluator(context: context)
    
    var config = self
    for (appName, app) in config.apps {
      let result = app.withExpressionsEvaluated(evaluator)
      switch result {
        case let .success(evaluatedConfig):
          config.apps[appName] = evaluatedConfig
        case let .failure(error):
          return .failure(.failedToEvaluateExpressions(app: appName, error))
      }
    }
    
    return .success(config)
  }
  
  /// Loads configuration from the `Bundler.toml` file in the given directory.
  /// - Parameters:
  ///   - packageDirectory: The directory containing the configuration file.
  ///   - evaluatorContext: Used to evaluate configuration values that support expressions.
  /// - Returns: The configuration.
  static func load(fromDirectory packageDirectory: URL, evaluatorContext: ExpressionEvaluator.Context) -> Result<Configuration, ConfigurationError> {
    let configurationFile = packageDirectory.appendingPathComponent("Bundler.toml")
    
    let contents: String
    do {
      contents = try String(contentsOf: configurationFile)
    } catch {
      return .failure(.failedToReadConfigurationFile(error))
    }
    
    let dto: ConfigurationDTO
    do {
      dto = try TOMLDecoder().decode(
        ConfigurationDTO.self,
        from: contents)
    } catch {
      return .failure(.failedToDeserializeConfiguration(error))
    }
    
    let configuration = Configuration(dto)
    return configuration.withExpressionsEvaluated(evaluatorContext)
  }
}
