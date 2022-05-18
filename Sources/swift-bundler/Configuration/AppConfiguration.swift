import Foundation

/// The configuration for an app.
struct AppConfiguration: Codable {
  /// The app's identifier (e.g. `com.example.ExampleApp`).
  var identifier: String
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
  /// String values can contain variable substitutions (see ``ExpressionEvaluator`` for details).
  var plist: [String: PlistValue]?

  enum CodingKeys: String, CodingKey {
    case product
    case version
    case category
    case identifier = "identifier"
    case minimumMacOSVersion = "minimum_macos_version"
    case minimumIOSVersion = "minimum_ios_version"
    case icon
    case plist
  }

  /// Appends the contents of the given `Info.plist` file to the app's configuration.
  /// - Parameter infoPlistFile: The file to load plist entries from.
  /// - Returns: The new configuration, or a failure if an error occurs.
  func appendingInfoPlistEntries(from infoPlistFile: URL) -> Result<AppConfiguration, AppConfigurationError> {
    let excludedKeys: Set<String> = [
      "CFBundleExecutable",
      "CFBundleIdentifier",
      "CFBundleInfoDictionaryVersion",
      "CFBundleNam",
      "CFBundlePackageType",
      "CFBundleShortVersionString",
      "CFBundleSignature",
      "CFBundleVersion",
      "LSRequiresIPhoneOS"
    ]

    let dictionary: [String: PlistValue]
    switch PlistValue.load(fromPlistFile: infoPlistFile) {
      case .success(let value):
        dictionary = value.filter { key, _ in
          !excludedKeys.contains(key)
        }
      case .failure(let error):
        return .failure(.failedToLoadInfoPlistEntries(file: infoPlistFile, error: error))
    }

    var configuration = self
    configuration.plist = configuration.plist.map { plist in
      var plist = plist
      for (key, value) in dictionary {
        plist[key] = value
      }
      return plist
    } ?? dictionary

    return .success(configuration)
  }
}
