import Foundation

/// The old configuration format (from swift-bundler 1.x.x). Kept for use in automatic configuration migration.
struct OldPackageConfiguration: Codable {
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
  static func load(from file: URL) -> Result<OldPackageConfiguration, PackageConfigurationError> {
    let data: Data
    do {
      data = try Data(contentsOf: file)
    } catch {
      return .failure(.failedToReadContentsOfOldConfigurationFile(file, error))
    }

    var configuration: OldPackageConfiguration
    do {
      configuration = try JSONDecoder().decode(OldPackageConfiguration.self, from: data)

      // Load the `extraInfoPlistEntries` property if present
      let json = try JSONSerialization.jsonObject(with: data)
      if let json = json as? [String: Any], let extraEntries = json["extraInfoPlistEntries"] as? [String: Any] {
        configuration.extraInfoPlistEntries = extraEntries
      }
    } catch {
      return .failure(.failedToDeserializeOldConfiguration(error))
    }

    return .success(configuration)
  }
}
