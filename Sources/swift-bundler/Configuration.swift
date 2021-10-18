import Foundation

struct Configuration: Codable {
  var target: String
  var bundleIdentifier: String
  var versionString: String
  var buildNumber: Int
  var category: String
  var minOSVersion: String

  static func load(_ directory: URL) -> Configuration {
    do {
      let data = try Data(contentsOf: directory.appendingPathComponent("Bundle.json"))
      return try JSONDecoder().decode(Configuration.self, from: data)
    } catch {
      terminate("Failed to load config from Bundle.json. Please make sure that the current directory is setup for swift-bundler correctly; \(error)")
    }
  }
}