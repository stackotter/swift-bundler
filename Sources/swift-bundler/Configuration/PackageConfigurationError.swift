import Foundation

/// An error related to package configuration.
enum PackageConfigurationError: LocalizedError {
  case noSuchApp(String)
  case multipleAppsAndNoneSpecified
  case failedToEvaluateExpressions(ExpressionEvaluatorError)
  case failedToReadConfigurationFile(URL, Error)
  case failedToDeserializeConfiguration(Error)
  case failedToSerializeConfiguration(Error)
  case failedToWriteToConfigurationFile(URL, Error)
  case failedToReadContentsOfOldConfigurationFile(URL, Error)
  case failedToDeserializeOldConfiguration(Error)
  case failedToSerializeMigratedConfiguration(Error)
  case failedToWriteToMigratedConfigurationFile(URL, Error)
  case failedToCreateConfigurationBackup(Error)
  case failedToDeserializeV2Configuration(Error)
  case unsupportedFormatVersion(Int)

  var errorDescription: String? {
    switch self {
      case .noSuchApp(let name):
        return "There is no app called '\(name)'."
      case .multipleAppsAndNoneSpecified:
        return "This package contains multiple apps. You must provide the 'app-name' argument"
      case .failedToEvaluateExpressions(let error):
        return "Failed to evaluate all expressions: \(error.localizedDescription)"
      case .failedToReadConfigurationFile(let file, _):
        return "Failed to read the configuration file at '\(file.relativePath)'. Are you sure that it exists?"
      case .failedToDeserializeConfiguration(let error):
        let deserializationError = Self.deserializationErrorDescription(error)
        return "Failed to deserialize configuration: \(deserializationError)"
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
      case .failedToCreateConfigurationBackup:
        return "Failed to backup configuration file"
      case .failedToDeserializeV2Configuration(let error):
        let deserializationError = Self.deserializationErrorDescription(error)
        return "Failed to deserialize configuration for migration: \(deserializationError)"
    case .unsupportedFormatVersion(let formatVersion):
        return "Package configuration file has an invalid format version '\(formatVersion)' and could not"
             + " be automatically migrated. The latest format version is '\(PackageConfiguration.currentFormatVersion)'"
    }
  }

  /// Computes a human readable description for the provided deserialization related error.
  static func deserializationErrorDescription(_ error: Error) -> String {
    let description: String
    switch error {
      case DecodingError.keyNotFound(let codingKey, let context):
        if codingKey.stringValue == "bundle_identifier" {
          description = "'bundle_identifier' is required for app configuration to be migrated"
        } else {
          let path = context.codingPath.map(\.stringValue).joined(separator: ".")
          description = "Expected a value at '\(path)'"
        }
      case let error as PlistError:
        description = error.localizedDescription
      default:
        description = String(reflecting: error)
    }
    return description
  }
}
