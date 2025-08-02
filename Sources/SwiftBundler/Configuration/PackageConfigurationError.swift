import Foundation
import TOMLKit
import ErrorKit

extension PackageConfiguration {
  typealias Error = RichError<ErrorMessage>

  /// An error message related to ``PackageConfiguration``.
  enum ErrorMessage: Throwable, Equatable {
    case noSuchApp(String)
    case multipleAppsAndNoneSpecified
    case failedToEvaluateVariables
    case failedToReadConfigurationFile(URL)
    case failedToDeserializeConfiguration
    case failedToSerializeConfiguration
    case failedToWriteToConfigurationFile(URL)
    case failedToReadContentsOfOldConfigurationFile(URL)
    case failedToDeserializeOldConfiguration
    case failedToCreateConfigurationBackup
    case failedToDeserializeV2Configuration
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

    var userFriendlyMessage: String {
      switch self {
        case .noSuchApp(let name):
          return "There is no app called '\(name)'."
        case .multipleAppsAndNoneSpecified:
          return "This package contains multiple apps. You must provide the 'app-name' argument"
        case .failedToEvaluateVariables:
          return "Failed to evaluate all expressions"
        case .failedToReadConfigurationFile(let file):
          return
            "Failed to read the configuration file at '\(file.relativePath)'. Are you sure that it exists?"
        case .failedToDeserializeConfiguration:
          return "Failed to deserialize configuration"
        case .failedToSerializeConfiguration:
          return "Failed to serialize configuration"
        case .failedToWriteToConfigurationFile(let file):
          return "Failed to write to configuration file at '\(file.relativePath)"
        case .failedToDeserializeOldConfiguration:
          return "Failed to deserialize old configuration"
        case .failedToReadContentsOfOldConfigurationFile(let file):
          return "Failed to read contents of old configuration file at '\(file.relativePath)'"
        case .failedToCreateConfigurationBackup:
          return "Failed to backup configuration file"
        case .failedToDeserializeV2Configuration:
          return "Failed to deserialize configuration for migration"
        case .unsupportedFormatVersion(let formatVersion):
          return
            "Package configuration file has an invalid format version '\(formatVersion)' and could not"
            + " be automatically migrated. The latest format version is '\(PackageConfiguration.currentFormatVersion)'"
        case .configurationIsAlreadyUpToDate:
          return "Configuration file is already up-to-date"
      }
    }
  }
}
