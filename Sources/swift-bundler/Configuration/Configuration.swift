import Foundation
import TOMLKit

enum ConfigurationError: LocalizedError {
  case invalidAppName(String)
  case multipleAppsAndNoneSpecified
  case failedToEvaluateExpressions(app: String, AppConfigurationError)
  case failedToReadConfigurationFile(Error)
  case failedToDeserializeConfiguration(Error)
  case failedToSerializeConfiguration(Error)
  case failedToWriteToConfigurationFile(Error)
}

struct Configuration {
  /// The configuration specific to each app.
  var apps: [String: AppConfiguration]
  
  /// Gets the configuration for the specified app. If no app is specified and there is only one app, that app is used.
  /// - Parameter name: The name of the app to get.
  /// - Returns: The app's name and configuration. If no app is specified, and there is more than one app, a failure is returned.
  func getAppConfiguration(_ name: String?) -> Result<(name: String, app: AppConfiguration), ConfigurationError> {
    if let name = name {
      guard let selected = apps[name] else {
        return .failure(.invalidAppName(name))
      }
      return .success((name: name, app: selected))
    } else if let first = apps.first, apps.count == 1 {
      return .success((name: first.key, app: first.value))
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
  /// - Returns: The configuration.
  static func load(fromDirectory packageDirectory: URL) -> Result<Configuration, ConfigurationError> {
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
    return configuration.withExpressionsEvaluated(.init(packageDirectory: packageDirectory))
  }
  
  /// Creates a configuration file for the specified app and product in the given directory.
  /// - Parameters:
  ///   - directory: The directory to create the configuration file in.
  ///   - app: The name of the app.
  ///   - product: The name of the product.
  /// - Returns: If an error occurs, a failure is returned.
  static func createConfigurationFile(in directory: URL, app: String, product: String) -> Result<Void, ConfigurationError> {
    let configuration = ConfigurationDTO(apps: [
      app: AppConfigurationDTO(product: product, version: "0.1.0")
    ])
    
    let contents: String
    do {
      contents = try TOMLEncoder().encode(configuration)
    } catch {
      return .failure(.failedToSerializeConfiguration(error))
    }
    
    do {
      try contents.write(
        to: directory.appendingPathComponent("Bundler.toml"),
        atomically: false,
        encoding: .utf8)
    } catch {
      return .failure(.failedToWriteToConfigurationFile(error))
    }
    
    return .success()
  }
}
