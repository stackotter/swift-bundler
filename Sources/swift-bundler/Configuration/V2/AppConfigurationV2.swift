import Foundation

/// The configuration for an app made with Swift Bundler v2.
struct AppConfigurationV2: Codable {
  /// The app's identifier (e.g. `com.example.ExampleApp`). Wasn't mandatory in v2, but can't be automatically migrated unless present.
  var bundleIdentifier: String
  /// The name of the executable product.
  var product: String
  /// The app's current version.
  var version: String
  // swiftlint:disable:next line_length
  /// The app's category. See [Apple's documentation](https://developer.apple.com/documentation/bundleresources/information_property_list/lsapplicationcategorytype) for more details.
  var category: String?
  /// The minimum macOS version that the app can run on.
  var minimumMacOSVersion: String?
  /// The minimum iOS version that the app can run on.
  var minimumIOSVersion: String?
  /// The path to the app's icon.
  var icon: String?
  /// A dictionary containing extra entries to add to the app's `Info.plist` file.
  ///
  /// The values can contain variable substitutions (see ``ExpressionEvaluator`` for details).
  var extraPlistEntries: [String: String]?

  private enum CodingKeys: String, CodingKey {
    case product
    case version
    case category
    case bundleIdentifier = "bundle_identifier"
    case minimumMacOSVersion = "minimum_macos_version"
    case minimumIOSVersion = "minimum_ios_version"
    case icon
    case extraPlistEntries = "extra_plist_entries"
  }

  /// Migrates this configuration to the latest version.
  func migrate() -> AppConfiguration {
    let plist: [String: PlistValue]? = extraPlistEntries.map { entries in
      entries.mapValues { value in
        return .string(value)
      }
    }

    return AppConfiguration(
      identifier: bundleIdentifier,
      product: product,
      version: version,
      category: category,
      minimumMacOSVersion: minimumMacOSVersion,
      minimumIOSVersion: minimumIOSVersion,
      icon: icon,
      plist: plist 
    )
  }
}
