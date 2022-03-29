import Foundation

/// The intermediate format for an app's configuration. Used to get around not being able to provide default values for codable properties.
struct AppConfigurationDTO: Codable {
  /// The name of the executable product.
  var product: String
  /// The app's current version.
  var version: String
  /// The app's category. See [Apple's documentation](https://developer.apple.com/app-store/categories/) for more details.
  var category: String?
  /// The app's bundle identifier (e.g. `com.example.ExampleApp`).
  var bundleIdentifier: String?
  /// The minimum macOS version that the app can run on.
  var minMacOSVersion: String?
  /// A dictionary containing extra entries to add to the app's `Info.plist` file. The values can contain expressions (see ``ExpressionEvaluator`` for details).
  var extraPlistEntries: [String: String]?
  
  /// Creates a new intermediate app configuration representation.
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
  
  /// Creates the intermediate representation for an app configuration.
  /// - Parameter configuration: The app configuration.
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
  /// Converts the intermediate configuration representation to an app configuration.
  /// - Parameter dto: The intermediate configuration representation.
  init(_ dto: AppConfigurationDTO) {
    product = dto.product
    version = dto.version
    category = dto.category ?? Self.default.category
    bundleIdentifier = dto.bundleIdentifier ?? Self.default.bundleIdentifier
    minMacOSVersion = dto.minMacOSVersion ?? Self.default.minMacOSVersion
    extraPlistEntries = dto.extraPlistEntries ?? Self.default.extraPlistEntries
  }
}
