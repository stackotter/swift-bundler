import Foundation
import TOMLKit

/// The configuration for a package.
struct PackageConfiguration: Codable {
  /// The current configuration format version.
  static let currentFormatVersion = 2

  /// The configuration format version.
  var formatVersion: Int
  /// The configuration for each app in the package (packages can contain multiple apps). Maps app name to app configuration.
  var apps: [String: AppConfiguration]

  private enum CodingKeys: String, CodingKey {
    case formatVersion = "format_version"
    case apps
  }

  /// Creates a new package configuration.
  /// - Parameter apps: The package's apps.
  init(_ apps: [String: AppConfiguration]) {
    formatVersion = Self.currentFormatVersion
    self.apps = apps
  }

  // MARK: Static methods

  /// Loads configuration from the `Bundler.toml` file in the given directory. Attempts to migrate outdated configurations.
  /// - Parameters:
  ///   - packageDirectory: The directory containing the configuration file.
  ///   - customFile: A custom configuration file not at the standard location.
  /// - Returns: The configuration.
  static func load(
    fromDirectory packageDirectory: URL,
    customFile: URL? = nil
  ) -> Result<PackageConfiguration, PackageConfigurationError> {
    let configurationFile = customFile ?? packageDirectory.appendingPathComponent("Bundler.toml")

    // Migrate old configuration if no new configuration exists
    let shouldAttemptJSONMigration = customFile == nil
    if shouldAttemptJSONMigration {
      let oldConfigurationFile = packageDirectory.appendingPathComponent("Bundle.json")
      let configurationExists = FileManager.default.itemExists(at: configurationFile, withType: .file)
      let oldConfigurationExists = FileManager.default.itemExists(at: oldConfigurationFile, withType: .file)
      if oldConfigurationExists && !configurationExists {
        return migrateV1Configuration(from: oldConfigurationFile, to: configurationFile)
      }
    }

    let contents: String
    do {
      contents = try String(contentsOf: configurationFile)
    } catch {
      return .failure(.failedToReadConfigurationFile(configurationFile, error))
    }

    let configuration: PackageConfiguration
    do {
      configuration = try TOMLDecoder().decode(
        PackageConfiguration.self,
        from: contents
      )
    } catch {
      // Maybe the configuration is a Swift Bundler v2 configuration. Attempt to migrate it.
    migrationAttempt:
      do {
        let table = try TOMLTable(string: contents)
        guard !table.contains(key: CodingKeys.formatVersion.rawValue) else {
          break migrationAttempt
        }

        return migrateV2Configuration(configurationFile, shouldBackup: true)
      } catch {}

      return .failure(.failedToDeserializeConfiguration(error))
    }

    if configuration.formatVersion != PackageConfiguration.currentFormatVersion {
      return .failure(.unsupportedFormatVersion(configuration.formatVersion))
    }

    return VariableEvaluator.evaluateVariables(
      in: configuration,
      packageDirectory: packageDirectory
    ).mapError { error in
      return .failedToEvaluateVariables(error)
    }
  }

  /// Migrates a Swift Bundler `v2.0.0` configuration file to the current configuration format.
  ///
  /// Mutates the contents of the given configuration file.
  /// - Parameters:
  ///   - configurationFile: The configuration file to migrate.
  ///   - shouldBackup: If `true`, the original configuration file will be backed up to `Bundler.toml.orig`.
  /// - Returns: The migrated configuration.
  static func migrateV2Configuration(
    _ configurationFile: URL,
    shouldBackup: Bool
  ) -> Result<PackageConfiguration, PackageConfigurationError> {
    log.warning("'\(configurationFile.relativePath)' is outdated. Migrating it to the latest configuration format")

    let contents: String
    do {
      contents = try String(contentsOf: configurationFile)
    } catch {
      return .failure(.failedToReadConfigurationFile(configurationFile, error))
    }

    if shouldBackup {
      let backupFile = configurationFile.appendingPathExtension("orig")
      do {
        try contents.write(to: backupFile, atomically: false, encoding: .utf8)
      } catch {
        return .failure(.failedToCreateConfigurationBackup(error))
      }
      log.info("The original configuration has been backed up to '\(backupFile.relativePath)'")
    }

    let oldConfiguration: PackageConfigurationV2
    do {
      oldConfiguration = try TOMLDecoder().decode(
        PackageConfigurationV2.self,
        from: contents
      )
    } catch {
      return .failure(.failedToDeserializeV2Configuration(error))
    }

    let configuration = oldConfiguration.migrate()
    let encodedContents: String
    do {
      encodedContents = try TOMLEncoder().encode(configuration)
    } catch {
      return .failure(.failedToSerializeConfiguration(error))
    }

    do {
      try encodedContents.write(to: configurationFile, atomically: false, encoding: .utf8)
    } catch {
      return .failure(.failedToWriteToConfigurationFile(configurationFile, error))
    }

    return .success(configuration)
  }

  /// Migrates a `Bundle.json` to a `Bundler.toml` file.
  /// - Parameters:
  ///   - oldConfigurationFile: The `Bundle.json` file to migrate.
  ///   - newConfigurationFile: The `Bundler.toml` file to output to.
  /// - Returns: The converted configuration.
  static func migrateV1Configuration(
    from oldConfigurationFile: URL,
    to newConfigurationFile: URL
  ) -> Result<PackageConfiguration, PackageConfigurationError> {
    log.warning("No 'Bundler.toml' file was found, but a 'Bundle.json' file was")
    log.info("Migrating 'Bundle.json' to the new configuration format")

    return PackageConfigurationV1.load(
      from: oldConfigurationFile
    ).flatMap { oldConfiguration in
      var extraPlistEntries: [String: PlistValue] = [:]
      for (key, value) in oldConfiguration.extraInfoPlistEntries {
        if let value = value as? String {
          extraPlistEntries[key] = .string(value)
        }
      }

      if extraPlistEntries.count != oldConfiguration.extraInfoPlistEntries.count {
        log.warning(.init(stringLiteral:
          "Some entries in 'extraInfoPlistEntries' were not able to be converted to the new format (because they weren't strings)." +
          " These will have to be manually converted"
        ))
      }

      log.warning("Discarding 'buildNumber' because the new format has no build number field")

      let appConfiguration = AppConfiguration(
        identifier: oldConfiguration.bundleIdentifier,
        product: oldConfiguration.target,
        version: oldConfiguration.versionString,
        category: oldConfiguration.category,
        plist: extraPlistEntries.isEmpty ? nil : extraPlistEntries
      )

      let configuration = PackageConfiguration([oldConfiguration.target: appConfiguration])
      let newContents: String
      do {
        newContents = try TOMLEncoder().encode(configuration)
      } catch {
        return .failure(.failedToSerializeMigratedConfiguration(error))
      }

      do {
        try newContents.write(to: newConfigurationFile, atomically: false, encoding: .utf8)
      } catch {
        return .failure(.failedToWriteToMigratedConfigurationFile(newConfigurationFile, error))
      }

      log.info("Only the 'product' and 'version' fields are mandatory. You can delete any others that you don't need")
      log.info("'Bundle.json' was successfully migrated to 'Bundler.toml', you can now safely delete it")

      return .success(configuration)
    }
  }

  /// Creates a configuration file for the specified app and product in the given directory.
  /// - Parameters:
  ///   - directory: The directory to create the configuration file in.
  ///   - app: The name of the app.
  ///   - product: The name of the product.
  /// - Returns: If an error occurs, a failure is returned.
  static func createConfigurationFile(
    in directory: URL,
    app: String,
    product: String
  ) -> Result<Void, PackageConfigurationError> {
    let configuration = PackageConfiguration([
      app: AppConfiguration(
        identifier: "com.example.\(product)",
        product: product,
        version: "0.1.0"
      )
    ])

    let contents: String
    do {
      contents = try TOMLEncoder().encode(configuration)
    } catch {
      return .failure(.failedToSerializeConfiguration(error))
    }

    let file = directory.appendingPathComponent("Bundler.toml")
    do {
      try contents.write(
        to: file,
        atomically: false,
        encoding: .utf8
      )
    } catch {
      return .failure(.failedToWriteToConfigurationFile(file, error))
    }

    return .success()
  }

  // MARK: Instance methods

  /// Gets the configuration for the specified app. If no app is specified and there is only one app, that app is returned.
  /// - Parameter name: The name of the app to get.
  /// - Returns: The app's name and configuration. If no app is specified, and there is more than one app, a failure is returned.
  func getAppConfiguration(
    _ name: String?
  ) -> Result<(name: String, app: AppConfiguration), PackageConfigurationError> {
    if let name = name {
      guard let selected = apps[name] else {
        return .failure(.noSuchApp(name))
      }
      return .success((name: name, app: selected))
    } else if let first = apps.first, apps.count == 1 {
      return .success((name: first.key, app: first.value))
    } else {
      return .failure(.multipleAppsAndNoneSpecified)
    }
  }
}
