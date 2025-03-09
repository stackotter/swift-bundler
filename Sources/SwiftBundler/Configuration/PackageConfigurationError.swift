import Foundation
import TOMLKit

/// An error related to package configuration.
enum PackageConfigurationError: LocalizedError, Equatable {
  case noSuchApp(String)
  case multipleAppsAndNoneSpecified
  case failedToEvaluateVariables(VariableEvaluatorError)
  case failedToReadConfigurationFile(URL, Error)
  case failedToDeserializeConfiguration(Error)
  case failedToSerializeConfiguration(Error)
  case failedToWriteToConfigurationFile(URL, Error)
  case failedToReadContentsOfOldConfigurationFile(URL, Error)
  case failedToDeserializeOldConfiguration(Error)
  case failedToCreateConfigurationBackup(Error)
  case failedToDeserializeV2Configuration(Error)
  case unsupportedFormatVersion(Int)
  case configurationIsAlreadyUpToDate

  static func == (_ lhs: Self, _ rhs: Self) -> Bool {
    switch (lhs, rhs) {
      case (.noSuchApp, .noSuchApp): return true
      case (.multipleAppsAndNoneSpecified, .multipleAppsAndNoneSpecified): return true
      case (.failedToEvaluateVariables, .failedToEvaluateVariables): return true
      case (.failedToReadConfigurationFile, .failedToReadConfigurationFile): return true
      case (.failedToDeserializeConfiguration, .failedToDeserializeConfiguration): return true
      case (.failedToSerializeConfiguration, .failedToSerializeConfiguration): return true
      case (.failedToWriteToConfigurationFile, .failedToWriteToConfigurationFile): return true
      case (
        .failedToReadContentsOfOldConfigurationFile,
        .failedToReadContentsOfOldConfigurationFile
      ): return true
      case (.failedToDeserializeOldConfiguration, .failedToDeserializeOldConfiguration): return true
      case (.failedToCreateConfigurationBackup, .failedToCreateConfigurationBackup): return true
      case (.failedToDeserializeV2Configuration, .failedToDeserializeV2Configuration): return true
      case (.unsupportedFormatVersion, .unsupportedFormatVersion): return true
      case (.configurationIsAlreadyUpToDate, .configurationIsAlreadyUpToDate): return true
      default:
        return false
    }
  }

  var errorDescription: String? {
    switch self {
      case .noSuchApp(let name):
        return "There is no app called '\(name)'."
      case .multipleAppsAndNoneSpecified:
        return "This package contains multiple apps. You must provide the 'app-name' argument"
      case .failedToEvaluateVariables(let error):
        return "Failed to evaluate all expressions: \(error.localizedDescription)"
      case .failedToReadConfigurationFile(let file, _):
        return
          "Failed to read the configuration file at '\(file.relativePath)'. Are you sure that it exists?"
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
      case .failedToCreateConfigurationBackup:
        return "Failed to backup configuration file"
      case .failedToDeserializeV2Configuration(let error):
        let deserializationError = Self.deserializationErrorDescription(error)
        return "Failed to deserialize configuration for migration: \(deserializationError)"
      case .unsupportedFormatVersion(let formatVersion):
        return
          "Package configuration file has an invalid format version '\(formatVersion)' and could not"
          + " be automatically migrated. The latest format version is '\(PackageConfiguration.currentFormatVersion)'"
      case .configurationIsAlreadyUpToDate:
        return "Configuration file is already up-to-date"
    }
  }

  /// Computes a human readable description for the provided deserialization related error.
  static func deserializationErrorDescription(_ error: Error) -> String {
    switch error {
      case DecodingError.keyNotFound(let codingKey, let context):
        if codingKey.stringValue == "bundle_identifier" {
          return "'bundle_identifier' is required for app configuration to be migrated"
        } else {
          let path = CodingPath(context.codingPath)
          return "Expected a value at '\(path)'"
        }
      case let error as UnexpectedKeysError:
        if error.keys.count == 1, let path = error.keys.values.first {
          return "Encountered unexpected key \(CodingPath(path))"
        } else {
          let paths = error.keys.values.map(CodingPath.init)
          let pathsString = paths.map(\.description).joinedGrammatically()
          return """
            Encountered unexpected \(paths.count == 1 ? "key" : "keys") \
            \(pathsString)
            """
        }
      case let error as PlistError:
        return error.localizedDescription
      default:
        return String(reflecting: error)
    }
  }
}
