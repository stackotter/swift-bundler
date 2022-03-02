import Foundation
import TOMLKit

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
  
  /// Loads configuration from the `Bundler.toml` file in the given directory.
  /// - Parameter packageDirectory: The directory containing the configuration file.
  /// - Returns: The configuration.
  static func load(fromDirectory packageDirectory: URL) throws -> Configuration {
    do {
      let configurationFile = packageDirectory.appendingPathComponent("Bundler.toml")
      let dto = try TOMLDecoder().decode(
        ConfigurationDTO.self,
        from: try String(contentsOf: configurationFile))
      return Configuration(dto)
    } catch {
      throw ConfigurationError.failedToLoadConfiguration(error)
    }
  }
}
