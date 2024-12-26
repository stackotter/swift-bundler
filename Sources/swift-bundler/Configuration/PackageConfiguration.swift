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
  /// The configuration for each lib in the package. Maps library name to
  /// library configuration. Generally used when integrating libraries built
  /// with different build systems such as CMake.
  var projects: [String: ProjectConfiguration]

  private enum CodingKeys: String, CodingKey {
    case formatVersion = "format_version"
    case apps
    case projects
  }

  struct Flat {
    var formatVersion: Int
    var apps: [String: AppConfiguration.Flat]
    var projects: [String: ProjectConfiguration.Flat]

    /// Gets the configuration for the specified app. If no app is specified
    /// and there is only one app, that app is returned.
    /// - Parameter name: The name of the app to get.
    /// - Returns: The app's name and configuration. If no app is specified, and
    ///   there is more than one app, a failure is returned.
    func getAppConfiguration(
      _ name: String?
    ) -> Result<
      (name: String, app: AppConfiguration.Flat),
      PackageConfigurationError
    > {
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

  /// Creates a new package configuration.
  /// - Parameter apps: The package's apps.
  /// - Parameter projects: The package's subprojects.
  init(
    apps: [String: AppConfiguration] = [:],
    projects: [String: ProjectConfiguration] = [:]
  ) {
    formatVersion = Self.currentFormatVersion
    self.apps = apps
    self.projects = projects
  }

  // MARK: Static methods

  /// Loads configuration from the `Bundler.toml` file in the given directory. Attempts to migrate outdated configurations.
  /// - Parameters:
  ///   - packageDirectory: The directory containing the configuration file.
  ///   - customFile: A custom configuration file not at the standard location.
  ///   - migrateConfiguration: If `true`, configuration is written to disk if the file is an old
  ///     configuration file and an error is thrown if the configuration is already at the latest
  ///     version.
  /// - Returns: The configuration.
  static func load(
    fromDirectory packageDirectory: URL,
    customFile: URL? = nil,
    migrateConfiguration: Bool = false
  ) -> Result<PackageConfiguration, PackageConfigurationError> {
    let configurationFile = customFile ?? packageDirectory.appendingPathComponent("Bundler.toml")

    // Migrate old configuration if no new configuration exists
    let shouldAttemptJSONMigration = customFile == nil
    if shouldAttemptJSONMigration {
      let oldConfigurationFile = packageDirectory.appendingPathComponent("Bundle.json")
      let configurationExists = FileManager.default.itemExists(
        at: configurationFile,
        withType: .file
      )
      let oldConfigurationExists = FileManager.default.itemExists(
        at: oldConfigurationFile,
        withType: .file
      )
      if oldConfigurationExists && !configurationExists {
        return migrateV1Configuration(
          from: oldConfigurationFile,
          to: migrateConfiguration ? configurationFile : nil
        )
      }
    }

    return String.read(from: configurationFile)
      .mapError { error in
        .failedToReadConfigurationFile(configurationFile, error)
      }
      .andThen { contents in
        Result {
          try TOMLDecoder(strictDecoding: true).decode(
            PackageConfiguration.self,
            from: contents
          )
        }
        .mapError(PackageConfigurationError.failedToDeserializeConfiguration)
        .andThen { configuration in
          if migrateConfiguration {
            return .failure(.configurationIsAlreadyUpToDate)
          } else {
            return .success(configuration)
          }
        }
        .tryRecover(unless: [.configurationIsAlreadyUpToDate]) {
          (error) -> Result<PackageConfiguration, PackageConfigurationError> in
          // Maybe the configuration is a Swift Bundler v2 configuration.
          // Attempt to migrate it.
          Result {
            try TOMLTable(string: contents)
          }
          .mapError(PackageConfigurationError.failedToDeserializeConfiguration)
          .andThen { table in
            guard !table.contains(key: CodingKeys.formatVersion.rawValue) else {
              return .failure(error)
            }

            return migrateV2Configuration(
              configurationFile,
              mode: migrateConfiguration ? .writeChanges(backup: true) : .readOnly
            )
          }
        }
      }
      .andThenDoSideEffect { configuration in
        guard configuration.formatVersion == PackageConfiguration.currentFormatVersion else {
          return .failure(.unsupportedFormatVersion(configuration.formatVersion))
        }
        return .success()
      }
      .andThen { configuration in
        VariableEvaluator.evaluateVariables(
          in: configuration,
          packageDirectory: packageDirectory
        ).mapError { error in
          return .failedToEvaluateVariables(error)
        }
      }
  }

  /// Migrates a Swift Bundler `v2.0.0` configuration file to the current configuration format.
  ///
  /// Mutates the contents of the given configuration file.
  /// - Parameters:
  ///   - configurationFile: The configuration file to migrate.
  ///   - mode: The migration mode to use.
  /// - Returns: The migrated configuration.
  static func migrateV2Configuration(
    _ configurationFile: URL,
    mode: MigrationMode
  ) -> Result<PackageConfiguration, PackageConfigurationError> {
    if mode == .readOnly {
      log.warning("'\(configurationFile.relativePath)' is outdated.")
      log.warning("Run 'swift bundler migrate' to migrate it to the latest config format.")
    }

    return String.read(from: configurationFile)
      .mapError { error in
        PackageConfigurationError
          .failedToReadConfigurationFile(configurationFile, error)
      }
      .andThenDoSideEffect { contents in
        // Back up the file if requested.
        guard mode == .writeChanges(backup: true) else {
          return .success()
        }

        let backupFile = configurationFile.appendingPathExtension("orig")
        return contents.write(to: configurationFile)
          .mapError(PackageConfigurationError.failedToCreateConfigurationBackup)
          .ifSuccess { _ in
            log.info(
              """
              The original configuration has been backed up to \
              '\(backupFile.relativePath)'
              """
            )
          }
      }
      .andThen { contents in
        // Decode the old configuration
        TOMLDecoder().decode(PackageConfigurationV2.self, from: contents)
          .mapError(PackageConfigurationError.failedToDeserializeV2Configuration)
      }
      .map { oldConfiguration in
        // Migrate the configuration
        oldConfiguration.migrate()
      }
      .andThenDoSideEffect { configuration in
        // Write the changes if requested
        guard case .writeChanges = mode else {
          return .success()
        }

        log.info("Writing migrated config to disk.")
        return writeConfiguration(configuration, to: configurationFile)
      }
  }

  /// Migrates a `Bundle.json` to a `Bundler.toml` file.
  /// - Parameters:
  ///   - oldConfigurationFile: The `Bundle.json` file to migrate.
  ///   - newConfigurationFile: The `Bundler.toml` file to output to. If `nil` the migrated
  ///     configuration is not written to disk.
  /// - Returns: The converted configuration.
  static func migrateV1Configuration(
    from oldConfigurationFile: URL,
    to newConfigurationFile: URL?
  ) -> Result<PackageConfiguration, PackageConfigurationError> {
    log.warning("No 'Bundler.toml' file was found, but a 'Bundle.json' file was")
    if newConfigurationFile == nil {
      log.warning("Use 'swift bundler migrate' to update your configuration to the latest format")
    } else {
      log.info("Migrating 'Bundle.json' to the new configuration format")
    }

    return PackageConfigurationV1.load(
      from: oldConfigurationFile
    )
    .map { oldConfiguration in
      oldConfiguration.migrate()
    }
    .andThenDoSideEffect { newConfiguration in
      guard let newConfigurationFile = newConfigurationFile else {
        return .success()
      }

      return writeConfiguration(newConfiguration, to: newConfigurationFile)
        .ifSuccess { _ in
          log.info(
            """
            Only the 'product' and 'version' fields are mandatory. You can \
            delete any others that you don't need
            """
          )
          log.info(
            """
            'Bundle.json' was successfully migrated to 'Bundler.toml', you can \
            now safely delete it
            """
          )
        }
    }
  }

  /// Writes the given configuration to the given file.
  static func writeConfiguration(
    _ configuration: PackageConfiguration,
    to file: URL
  ) -> Result<Void, PackageConfigurationError> {
    Result {
      try TOMLEncoder().encode(configuration)
    }
    .mapError(PackageConfigurationError.failedToSerializeConfiguration)
    .andThen { newContents in
      Result {
        try newContents.write(to: file, atomically: false, encoding: .utf8)
      }.mapError { error in
        .failedToWriteToConfigurationFile(file, error)
      }
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
    let configuration = PackageConfiguration(
      apps: [
        app: AppConfiguration(
          identifier: "com.example.\(product)",
          product: product,
          version: "0.1.0"
        )
      ]
    )
    let file = directory.appendingPathComponent("Bundler.toml")

    return writeConfiguration(configuration, to: file)
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
