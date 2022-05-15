import Foundation

/// The configuration for a package made with Swift Bundler v2.
struct PackageConfigurationV2: Codable {
  /// The configuration for each app in the package (packages can contain multiple apps). Maps app name to app configuration.
  var apps: [String: AppConfigurationV2]

  /// Migrates this configuration to the latest version.
  func migrate() -> PackageConfiguration {
    return PackageConfiguration(
      apps.mapValues { app in
        return app.migrate()
      }
    )
  }
}
