import Foundation

struct AppConfigurationDTO: Codable {
  var target: String
  var version: String?
  var category: String?
  var bundleIdentifier: String?
  var minMacOSVersion: String?
  var plistEntries: [String: PlistValue]?
  
  init(_ configuration: AppConfiguration) {
    target = configuration.target
    version = configuration.version
    category = configuration.category
    bundleIdentifier = configuration.bundleIdentifier
    minMacOSVersion = configuration.minMacOSVersion
    plistEntries = configuration.plistEntries
  }
}

extension AppConfiguration {
  init(_ dto: AppConfigurationDTO) {
    target = dto.target
    version = dto.version ?? Self.default.version
    category = dto.category ?? Self.default.category
    bundleIdentifier = dto.bundleIdentifier ?? Self.default.bundleIdentifier
    minMacOSVersion = dto.minMacOSVersion ?? Self.default.minMacOSVersion
    plistEntries = dto.plistEntries ?? Self.default.plistEntries
  }
}
