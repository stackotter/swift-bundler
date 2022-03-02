import Foundation
import TOMLKit

enum ConfigurationError: LocalizedError {
  case failedToLoadConfiguration(Error)
  case failedToGetSelectedApp(String)
}

/// A utility for handling configuration.
enum ConfigurationUtil {
  /// Loads configuration from the `Bundler.toml` file in the given directory.
  /// - Parameter packageDirectory: The directory containing the configuration file.
  /// - Returns: The configuration.
  static func loadConfiguration(fromDirectory packageDirectory: URL) throws -> Configuration {
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
