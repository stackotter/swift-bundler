import Foundation

/// The old configuration format (from swift-bundler 1.x.x)
struct OldConfiguration: Codable {
  var target: String
  var bundleIdentifier: String
  var versionString: String
  var buildNumber: Int
  var category: String
  var minOSVersion: String
  
  var extraInfoPlistEntries: [String: Any] = [:]
  
  enum CodingKeys: String, CodingKey {
    case target, bundleIdentifier, versionString, buildNumber, category, minOSVersion
  }
  
  /// Loads the configuration from a `Bundle.json` file.
  /// - Parameter file: The file to load the configuration from.
  /// - Returns: The configuration.
  static func load(from file: URL) -> Result<OldConfiguration, ConfigurationError> {
    let data: Data
    do {
      data = try Data(contentsOf: file)
    } catch {
      return .failure(.failedToReadContentsOfOldConfigurationFile(error))
    }
    
    var configuration: OldConfiguration
    do {
      configuration = try JSONDecoder().decode(OldConfiguration.self, from: data)
      
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
