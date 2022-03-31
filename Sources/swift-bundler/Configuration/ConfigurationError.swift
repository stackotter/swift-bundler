import Foundation

/// An error related to package configuration.
enum ConfigurationError: LocalizedError {
  case noSuchApp(String)
  case multipleAppsAndNoneSpecified
  case failedToEvaluateExpressions(app: String, AppConfigurationError)
  case failedToReadConfigurationFile(URL, Error)
  case failedToDeserializeConfiguration(Error)
  case failedToSerializeConfiguration(Error)
  case failedToWriteToConfigurationFile(URL, Error)
  case failedToReadContentsOfOldConfigurationFile(URL, Error)
  case failedToDeserializeOldConfiguration(Error)
  case failedToSerializeMigratedConfiguration(Error)
  case failedToWriteToMigratedConfigurationFile(URL, Error)

  var errorDescription: String? {
    switch self {
      case .noSuchApp(let name):
        return "There is no app called '\(name)'."
      case .multipleAppsAndNoneSpecified:
        return "This package contains multiple apps. You must provide the 'app-name' argument"
      case .failedToEvaluateExpressions(let app, let appConfigurationError):
        return "Failed to evaluate the '\(app)' app's configuration: \(appConfigurationError.localizedDescription)"
      case .failedToReadConfigurationFile(let file, _):
        return "Failed to read the configuration file at '\(file.relativePath)'. Are you sure that it exists?"
      case .failedToDeserializeConfiguration(let error):
        return "Failed to deserialize configuration: \(error.localizedDescription)"
      case .failedToSerializeConfiguration:
        return "Failed to serialize configuration"
      case .failedToWriteToConfigurationFile(let file, _):
        return "Failed to write to configuration file at '\(file.relativePath)"
      case .failedToDeserializeOldConfiguration(let error):
        return "Failed to deserialize old configuration: \(error.localizedDescription)"
      case .failedToReadContentsOfOldConfigurationFile(let file, _):
        return "Failed to read contents of old configuration file at '\(file.relativePath)'"
      case .failedToSerializeMigratedConfiguration:
        return "Failed to serialize migrated configuration"
      case .failedToWriteToMigratedConfigurationFile(let file, _):
        return "Failed to write migrated configuration to file at '\(file.relativePath)'"
    }
  }
}
