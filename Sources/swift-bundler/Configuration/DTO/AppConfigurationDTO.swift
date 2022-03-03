import Foundation

struct AppConfigurationDTO: Codable {
  var target: String
  var version: String?
  var category: String?
  var bundleIdentifier: String?
  var minMacOSVersion: String?
  var extraPlistEntries: [String: String]?
  
  init(_ configuration: AppConfiguration) {
    target = configuration.target
    version = configuration.version
    category = configuration.category
    bundleIdentifier = configuration.bundleIdentifier
    minMacOSVersion = configuration.minMacOSVersion
    extraPlistEntries = configuration.extraPlistEntries
  }
}

extension AppConfiguration {
  init(_ dto: AppConfigurationDTO) {
    target = dto.target
    version = dto.version ?? Self.default.version
    category = dto.category ?? Self.default.category
    bundleIdentifier = dto.bundleIdentifier ?? Self.default.bundleIdentifier
    minMacOSVersion = dto.minMacOSVersion ?? Self.default.minMacOSVersion
    extraPlistEntries = dto.extraPlistEntries ?? Self.default.extraPlistEntries
  }
}
