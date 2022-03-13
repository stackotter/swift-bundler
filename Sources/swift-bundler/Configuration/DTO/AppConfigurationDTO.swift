import Foundation

struct AppConfigurationDTO: Codable {
  var product: String
  var version: String
  var category: String?
  var bundleIdentifier: String?
  var minMacOSVersion: String?
  var extraPlistEntries: [String: String]?
  
  init(
    product: String,
    version: String,
    category: String? = nil,
    bundleIdentifier: String? = nil,
    minMacOSVersion: String? = nil,
    extraPlistEntries: [String : String]? = nil
  ) {
    self.product = product
    self.version = version
    self.category = category
    self.bundleIdentifier = bundleIdentifier
    self.minMacOSVersion = minMacOSVersion
    self.extraPlistEntries = extraPlistEntries
  }
  
  init(_ configuration: AppConfiguration) {
    product = configuration.product
    version = configuration.version
    category = configuration.category
    bundleIdentifier = configuration.bundleIdentifier
    minMacOSVersion = configuration.minMacOSVersion
    extraPlistEntries = configuration.extraPlistEntries
  }
}

extension AppConfiguration {
  init(_ dto: AppConfigurationDTO) {
    product = dto.product
    version = dto.version
    category = dto.category ?? Self.default.category
    bundleIdentifier = dto.bundleIdentifier ?? Self.default.bundleIdentifier
    minMacOSVersion = dto.minMacOSVersion ?? Self.default.minMacOSVersion
    extraPlistEntries = dto.extraPlistEntries ?? Self.default.extraPlistEntries
  }
}
