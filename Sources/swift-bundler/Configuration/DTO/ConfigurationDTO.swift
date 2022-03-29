import Foundation

/// The intermediate format for configurations. Used to get around not being able to provide default values for codable properties.
struct ConfigurationDTO: Codable {
  /// The apps contained within the package.
  var apps: [String: AppConfigurationDTO]

  private enum CodingKeys: String, CodingKey {
    case apps
  }
  
  /// Creates a new intermediate configuration representation.
  init(apps: [String : AppConfigurationDTO]) {
    self.apps = apps
  }
  
  /// Creates an intermediate configuration representation for a configuration.
  /// - Parameter configuration: The configuration.
  init(_ configuration: Configuration) {
    apps = configuration.apps.mapValues {
      AppConfigurationDTO($0)
    }
  }
}

extension Configuration {
  /// Converts the intermediate configuration representation to a configuration.
  /// - Parameter dto: The intermediate configuration representation.
  init(_ dto: ConfigurationDTO) {
    apps = dto.apps.mapValues {
      AppConfiguration($0)
    }
  }
}
