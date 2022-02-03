import Foundation

struct Configuration: Codable {
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

  static func load(_ directory: URL) -> Configuration {
    do {
      let data = try Data(contentsOf: directory.appendingPathComponent("Bundle.json"))
      var configuration = try JSONDecoder().decode(Configuration.self, from: data)
      
      // Load the `extraInfoPlistEntries` property if present
      let json = try JSONSerialization.jsonObject(with: data)
      if let json = json as? [String: Any], let extraEntries = json["extraInfoPlistEntries"] as? [String: Any] {
        configuration.extraInfoPlistEntries = extraEntries
      }
      
      return configuration
    } catch {
      terminate("Failed to load config from Bundle.json. Please make sure that the current directory is setup for swift-bundler correctly; \(error)")
    }
  }
}
