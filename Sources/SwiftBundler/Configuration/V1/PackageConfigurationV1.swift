import Foundation

/// The old configuration format (from swift-bundler 1.x.x). Kept for use in automatic configuration migration.
struct PackageConfigurationV1: Codable {
  /// The name of the app's executable target.
  var target: String
  /// The app's bundle identifier (e.g. `com.example.ExampleApp`).
  var bundleIdentifier: String
  /// The app's version string (e.g. `0.1.0`).
  var versionString: String
  /// The app's build number.
  var buildNumber: Int
  /// The app's category. See ``AppConfiguration/category``.
  var category: String
  /// The minimum macOS version that the app should run on.
  var minOSVersion: String

  /// A dictionary containing extra entries to add to the app's `Info.plist` file.
  var extraInfoPlistEntries: [String: Any] = [:]

  private enum CodingKeys: String, CodingKey {
    case target, bundleIdentifier, versionString, buildNumber, category, minOSVersion
  }

  /// Loads the configuration from a `Bundle.json` file.
  /// - Parameter file: The file to load the configuration from.
  /// - Returns: The configuration. If an error occurs, a failure is returned.
  static func load(
    from file: URL
  ) -> Result<PackageConfigurationV1, PackageConfigurationError> {
    // Load the file's contents
    Data.read(from: file)
      .mapError { error in
        .failedToReadContentsOfOldConfigurationFile(file, error)
      }
      .andThen { data in
        // Parse the configuration. The `extraInfoPlistEntries` field requires
        // special attention so we parse the configuration twice, once as a
        // PackageConfigurationV1 and once as a JSON object.
        JSONDecoder().decode(
          PackageConfigurationV1.self,
          from: data
        )
        .andThen { configuration in
          Result {
            try JSONSerialization.jsonObject(with: data)
          }
          .map { json in
            (configuration, json)
          }
        }
        .mapError(PackageConfigurationError.failedToDeserializeOldConfiguration)
      }
      .map { (configuration: PackageConfigurationV1, json: Any) in
        // Load the `extraInfoPlistEntries` property if present
        var configuration = configuration

        if let json = json as? [String: Any],
          let extraEntries = json["extraInfoPlistEntries"] as? [String: Any]
        {
          configuration.extraInfoPlistEntries = extraEntries
        }

        return configuration
      }
  }

  func migrate() -> PackageConfiguration {
    var extraPlistEntries: [String: PlistValue] = [:]
    for (key, value) in extraInfoPlistEntries {
      if let value = value as? String {
        extraPlistEntries[key] = .string(value)
      }
    }

    if extraPlistEntries.count != extraInfoPlistEntries.count {
      log.warning(
        """
        Some entries in 'extraInfoPlistEntries' were not able to be converted \
        to the new format (because they weren't strings). These will have to \
        be manually converted
        """
      )
    }

    log.warning(
      """
      Discarding 'buildNumber' because the latest config format has no build \
      number field
      """
    )

    let appConfiguration = AppConfiguration(
      identifier: bundleIdentifier,
      product: target,
      version: versionString,
      category: category,
      plist: extraPlistEntries.isEmpty ? nil : extraPlistEntries
    )

    return PackageConfiguration(apps: [target: appConfiguration])
  }
}
