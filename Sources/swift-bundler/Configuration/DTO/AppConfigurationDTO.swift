import Foundation

/// The intermediate format for an app's configuration. Used to get around not being able to provide default values for codable properties.
struct AppConfigurationDTO: Codable {
  /// The name of the executable product.
  var product: String
  /// The app's current version.
  var version: String
  /// The app's category. See [Apple's documentation](https://developer.apple.com/documentation/bundleresources/information_property_list/lsapplicationcategorytype) for more details.
  var category: String?
  /// The app's bundle identifier (e.g. `com.example.ExampleApp`).
  var bundleIdentifier: String?
  /// The minimum macOS version that the app can run on.
  var minimumMacOSVersion: String?
  /// The path to the app's icon.
  var icon: String?
  /// A dictionary containing extra entries to add to the app's `Info.plist` file. The values can contain variable substitutions (see ``ExpressionEvaluator`` for details).
  var extraPlistEntries: [String: String]?

  private enum CodingKeys: String, CodingKey {
    case product
    case version
    case category
    case bundleIdentifier = "bundle_identifier"
    case minimumMacOSVersion = "minimum_macos_version"
    case icon
    case extraPlistEntries = "extra_plist_entries"
  }
  
  /// Creates a new intermediate app configuration representation.
  init(
    product: String,
    version: String,
    category: String? = nil,
    bundleIdentifier: String? = nil,
    minimumMacOSVersion: String? = nil,
    icon: String? = nil,
    extraPlistEntries: [String : String]? = nil
  ) {
    self.product = product
    self.version = version
    self.category = category
    self.bundleIdentifier = bundleIdentifier
    self.minimumMacOSVersion = minimumMacOSVersion
    self.icon = icon
    self.extraPlistEntries = extraPlistEntries
  }
  
  /// Creates the intermediate representation for an app configuration.
  /// - Parameter configuration: The app configuration.
  init(_ configuration: AppConfiguration) {
    product = configuration.product
    version = configuration.version
    category = configuration.category
    bundleIdentifier = configuration.bundleIdentifier
    minimumMacOSVersion = configuration.minimumMacOSVersion
    icon = configuration.icon
    extraPlistEntries = configuration.extraPlistEntries
  }
}

extension AppConfiguration {
  /// Converts the intermediate configuration representation to an app configuration.
  /// - Parameter dto: The intermediate configuration representation.
  init(_ dto: AppConfigurationDTO) {
    product = dto.product
    version = dto.version
    category = dto.category
    bundleIdentifier = dto.bundleIdentifier ?? Self.default.bundleIdentifier
    minimumMacOSVersion = dto.minimumMacOSVersion ?? Self.default.minimumMacOSVersion
    icon = dto.icon
    extraPlistEntries = dto.extraPlistEntries ?? Self.default.extraPlistEntries
  }
}
