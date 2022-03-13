import Foundation

struct ConfigurationDTO: Codable {
  var apps: [String: AppConfigurationDTO]
  
  init(apps: [String : AppConfigurationDTO]) {
    self.apps = apps
  }
  
  init(_ configuration: Configuration) {
    apps = configuration.apps.mapValues {
      AppConfigurationDTO($0)
    }
  }
}

extension Configuration {
  init(_ dto: ConfigurationDTO) {
    apps = dto.apps.mapValues {
      AppConfiguration($0)
    }
  }
}
