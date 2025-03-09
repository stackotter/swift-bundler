import Foundation
import TOMLKit
import Version

/// A utility for creating packages from package templates.
enum Templater {
  /// The repository of default templates.
  static let defaultTemplateRepository = "https://github.com/stackotter/swift-bundler-templates"

  /// Creates a package using an optionally specified template from the default
  /// template repository.
  ///
  /// Downloads the default template repository if it hasn't already been downloaded.
  /// - Parameters:
  ///   - outputDirectory: The directory to create the package in.
  ///   - template: The template to use to create the package.
  ///   - packageName: The name of the package.
  ///   - configuration: The app's configuration.
  ///   - forceCreation: If `true`, the package will be created even if the
  ///     selected template doesn't support the user's system and Swift version.
  ///   - indentationStyle: The indentation style to use.
  ///   - addVSCodeOverlay: If `true`, the VSCode overlay (containing
  ///     `launch.json` and `.vscode/tasks.json`), will be added to the package
  ///     (enabling ergonomic debugging with VSCode).
  /// - Returns: The template that the package was created from (or nil if none
  ///   were used), or a failure if package creation failed.
  static func createPackage(
    in outputDirectory: URL,
    from template: String?,
    packageName: String,
    configuration: AppConfiguration,
    forceCreation: Bool,
    indentationStyle: IndentationStyle,
    addVSCodeOverlay: Bool
  ) async -> Result<Template?, TemplaterError> {
    if FileManager.default.fileExists(atPath: outputDirectory.path) {
      return .failure(.packageDirectoryAlreadyExists(outputDirectory))
    }

    // If no template is specified, create the most basic package that just
    // prints 'Hello, World!'
    guard let template = template else {
      log.info("Creating package")

      return await SwiftPackageManager.createPackage(
        in: outputDirectory,
        name: packageName
      ).mapError { error -> TemplaterError in
        .failedToCreateBareMinimumPackage(error)
      }.andThen { _ in
        log.info("Updating indentation to '\(indentationStyle.defaultValueDescription)'")
        return updateIndentationStyle(in: outputDirectory, from: .spaces(4), to: indentationStyle)
      }.mapError { error -> TemplaterError in
        attemptCleanup(outputDirectory)
        return error
      }.andThen { (_: Void) -> Result<Void, TemplaterError> in
        return createPackageConfigurationFile(
          in: outputDirectory,
          packageName: packageName,
          configuration: configuration
        )
      }.map { (_: Void) -> Template? in
        // No template was used
        return nil
      }
    }

    // If a template was specified: Get the default templates directory (and download if not present), and then create the package
    return await getDefaultTemplatesDirectory(downloadIfNecessary: true)
      .andThen { templatesDirectory in
        await createPackage(
          in: outputDirectory,
          from: template,
          in: templatesDirectory,
          packageName: packageName,
          configuration: configuration,
          forceCreation: forceCreation,
          indentationStyle: indentationStyle,
          addVSCodeOverlay: addVSCodeOverlay
        )
      }.map { template in
        .some(template)
      }
  }

  /// Creates a package from the specified template from the specified template repository.
  /// - Parameters:
  ///   - outputDirectory: The directory to create the package in.
  ///   - template: The template to use to create the package.
  ///   - templatesDirectory: The directory containing the template to use.
  ///   - packageName: The name of the package.
  ///   - configuration: The package's configuration.
  ///   - forceCreation: If `true`, the package will be created even if the selected template doesn't support the user's system and Swift version.
  ///   - indentationStyle: The indentation style to use.
  ///   - addVSCodeOverlay: If `true`, the VSCode overlay (containing `launch.json` and `.vscode/tasks.json`),
  ///     will be added to the package (enabling ergonomic debugging with VSCode).
  /// - Returns: The template that the package was created from, or a failure if package creation failed.
  static func createPackage(
    in outputDirectory: URL,
    from template: String,
    in templatesDirectory: URL,
    packageName: String,
    configuration: AppConfiguration,
    forceCreation: Bool,
    indentationStyle: IndentationStyle,
    addVSCodeOverlay: Bool
  ) async -> Result<Template, TemplaterError> {
    if FileManager.default.fileExists(atPath: outputDirectory.path) {
      return .failure(.packageDirectoryAlreadyExists(outputDirectory))
    }

    // The `Base` template should not be used to create packages directly
    guard template != "Base" else {
      return .failure(.cannotCreatePackageFromBaseTemplate)
    }

    log.info("Creating package from the '\(template)' template")

    // Check that the template exists
    let templateDirectory = templatesDirectory.appendingPathComponent(template)
    guard FileManager.default.itemExists(at: templateDirectory, withType: .directory) else {
      return .failure(.noSuchTemplate(template))
    }

    // Load the template manifest
    let manifestFile = templateDirectory.appendingPathComponent("Template.toml")
    let manifest: TemplateManifest
    switch TemplateManifest.load(from: manifestFile, template: template) {
      case let .success(templateManifest):
        manifest = templateManifest
      case let .failure(error):
        return .failure(error)
    }

    if !forceCreation {
      // Verify that this machine's Swift version is supported
      if case let .failure(error) = await verifyTemplateIsSupported(template, manifest) {
        return .failure(error)
      }
    }

    // Create the output directory
    if case let .failure(error) = FileManager.default.createDirectory(at: outputDirectory) {
      return .failure(.failedToCreateOutputDirectory(outputDirectory, error))
    }

    // Apply the base template first if it exists
    let baseTemplate = templatesDirectory.appendingPathComponent("Base")
    if FileManager.default.itemExists(at: baseTemplate, withType: .directory) {
      // Set the indentation style to tab for now to avoid updating the tab style twice
      // because the final `applyTemplate` call will update all files in the output directory
      let result = applyTemplate(
        baseTemplate,
        to: outputDirectory,
        packageName: packageName,
        identifier: configuration.identifier,
        indentationStyle: indentationStyle
      )

      if case let .failure(error) = result {
        attemptCleanup(outputDirectory)
        return .failure(error)
      }
    }

    if addVSCodeOverlay {
      let vsCodeOverlay = templatesDirectory.appendingPathComponent("VSCode")
      guard FileManager.default.itemExists(at: vsCodeOverlay, withType: .directory) else {
        return .failure(.missingVSCodeOverlay)
      }

      let result = applyTemplate(
        vsCodeOverlay,
        to: outputDirectory,
        packageName: packageName,
        identifier: configuration.identifier,
        indentationStyle: indentationStyle
      )

      if case let .failure(error) = result {
        attemptCleanup(outputDirectory)
        return .failure(error)
      }
    }

    // Apply the template
    return await applyTemplate(
      templateDirectory,
      to: outputDirectory,
      packageName: packageName,
      identifier: configuration.identifier,
      indentationStyle: indentationStyle
    ).mapError { error in
      // Cleanup output directory
      attemptCleanup(outputDirectory)
      return error
    }.andThen { _ -> Result<Void, TemplaterError> in
      createPackageConfigurationFile(
        in: outputDirectory,
        packageName: packageName,
        configuration: configuration
      )
    }.map { _ in
      Template(name: template, manifest: manifest)
    }
  }

  static func createPackageConfigurationFile(
    in packageDirectory: URL,
    packageName: String,
    configuration: AppConfiguration
  ) -> Result<Void, TemplaterError> {
    // Create package configuration file
    let file = packageDirectory.appendingPathComponent("Bundler.toml")
    let configuration = PackageConfiguration(apps: [
      packageName: configuration
    ])

    do {
      let contents = try TOMLEncoder().encode(configuration)
      try contents.write(to: file, atomically: false, encoding: .utf8)
      return .success()
    } catch {
      return .failure(.failedToCreateConfigurationFile(configuration, file, error))
    }
  }

  /// Verifies that the given template supports this machine's Swift version.
  /// - Returns: An error if this machine's Swift version is not supported by the template.
  static func verifyTemplateIsSupported(
    _ name: String,
    _ manifest: TemplateManifest
  ) async -> Result<Void, TemplaterError> {
    // Verify that the installed Swift version is supported
    switch await SwiftPackageManager.getSwiftVersion() {
      case .success(let version):
        if version < manifest.minimumSwiftVersion {
          return .failure(
            .templateDoesNotSupportInstalledSwiftVersion(
              template: name,
              version: version,
              minimumSupportedVersion: manifest.minimumSwiftVersion
            ))
        }
      case .failure(let error):
        return .failure(.failedToCheckSwiftVersion(error))
    }

    return .success()
  }

  /// Gets the default templates directory.
  /// - Parameter downloadIfNecessary: If `true` the default templates
  ///   repository is downloaded if the templates directory doesn't exist.
  /// - Returns: The default templates directory, or a failure if the templates
  ///   directory doesn't exist and couldn't be downloaded.
  static func getDefaultTemplatesDirectory(
    downloadIfNecessary: Bool
  ) async -> Result<URL, TemplaterError> {
    // Get the templates directory
    let templatesDirectory: URL
    switch System.getApplicationSupportDirectory() {
      case let .success(applicationSupport):
        templatesDirectory = applicationSupport.appendingPathComponent("templates")
      case let .failure(error):
        return .failure(.failedToGetApplicationSupportDirectory(error))
    }

    // Download the templates if they don't exist
    if !FileManager.default.itemExists(at: templatesDirectory, withType: .directory) {
      let result = await downloadDefaultTemplates(into: templatesDirectory)
      if case let .failure(error) = result {
        return .failure(error)
      }
    }

    return .success(templatesDirectory)
  }

  /// Updates the default templates to the latest version from GitHub.
  /// - Returns: A failure if updating fails.
  static func updateTemplates() async -> Result<Void, TemplaterError> {
    return await getDefaultTemplatesDirectory(downloadIfNecessary: false)
      .andThen { templatesDirectory in
        guard FileManager.default.itemExists(at: templatesDirectory, withType: .directory) else {
          return await downloadDefaultTemplates(into: templatesDirectory)
        }

        return await Process.create(
          "git",
          arguments: [
            "fetch"
          ],
          directory: templatesDirectory
        ).runAndWait().andThen { _ in
          await Process.create(
            "git",
            arguments: [
              "checkout", "v\(SwiftBundler.version.major)",
            ],
            directory: templatesDirectory
          ).runAndWait()
        }.andThen { _ in
          await Process.create(
            "git",
            arguments: ["pull"],
            directory: templatesDirectory
          ).runAndWait()
        }.mapError(TemplaterError.failedToPullLatestTemplates)
      }
  }

  /// Gets the list of available templates from the default templates directory.
  /// - Returns: The available templates, or an error if template enumeration fails.
  static func enumerateTemplates() async -> Result<[Template], TemplaterError> {
    await getDefaultTemplatesDirectory(downloadIfNecessary: true)
      .andThen(enumerateTemplates(in:))
  }

  /// Gets the list of available templates from a templates directory.
  /// - Parameter templatesDirectory: The directory to search for templates in.
  /// - Returns: The available templates, or an error if template enumeration fails.
  static func enumerateTemplates(in templatesDirectory: URL) -> Result<[Template], TemplaterError> {
    do {
      let contents = try FileManager.default.contentsOfDirectory(
        at: templatesDirectory, includingPropertiesForKeys: nil, options: [])
      var templates: [Template] = []

      // Enumerate templates
      for directory in contents {
        guard FileManager.default.itemExists(at: directory, withType: .directory) else {
          continue
        }

        let templateName = directory.lastPathComponent

        // Skip `Base` template, `VSCode` template, and `.git` directory
        guard
          templateName != "Base" && templateName != "VSCode" && !templateName.starts(with: ".")
        else {
          continue
        }

        // Load the template manifest file
        let manifestFile = directory.appendingPathComponent("Template.toml")
        let manifest: TemplateManifest
        switch TemplateManifest.load(from: manifestFile, template: templateName) {
          case let .success(templateManifest):
            manifest = templateManifest
          case let .failure(error):
            return .failure(error)
        }

        let template = Template(name: templateName, manifest: manifest)
        templates.append(template)
      }

      return .success(templates)
    } catch {
      return .failure(.failedToEnumerateTemplates(error))
    }
  }

  /// Downloads the default template repository.
  /// - Parameter directory: The directory to clone the template repository in.
  /// - Returns: A failure if cloning the repository fails.
  static func downloadDefaultTemplates(into directory: URL) async -> Result<Void, TemplaterError> {
    log.info("Downloading default templates (\(defaultTemplateRepository))")

    // Remove the directory if it already exists
    try? FileManager.default.removeItem(at: directory)

    // Clone the templates repository
    let process = Process.create(
      "git",
      arguments: [
        "clone", "-b", "v\(SwiftBundler.version.major)",
        "\(defaultTemplateRepository)",
        directory.path,
      ]
    )

    return await process.runAndWait()
      .mapError { error in
        .failedToCloneTemplateRepository(error)
      }
  }

  /// Applies a template to a directory (processes and copies the template's files).
  /// - Parameters:
  ///   - templateDirectory: The template's directory.
  ///   - outputDirectory: The directory to copy the resulting files to.
  ///   - packageName: The name of the package.
  ///   - identifier: The package's identifier (e.g. 'com.example.ExampleApp').
  ///   - indentationStyle: The style of indentation to use.
  /// - Returns: A failure if template application fails.
  static func applyTemplate(
    _ templateDirectory: URL,
    to outputDirectory: URL,
    packageName: String,
    identifier: String,
    indentationStyle: IndentationStyle
  ) -> Result<Void, TemplaterError> {
    log.info("Applying '\(templateDirectory.lastPathComponent)' template")

    guard
      let enumerator = FileManager.default.enumerator(
        at: templateDirectory, includingPropertiesForKeys: nil)
    else {
      return .failure(
        .failedToEnumerateTemplateContents(template: templateDirectory.lastPathComponent))
    }

    // Enumerate the template's files
    let excluded = Set(["Template.toml"])
    let files =
      enumerator
      .compactMap { $0 as? URL }
      .filter { !excluded.contains($0.lastPathComponent) }
      .filter { FileManager.default.itemExists(at: $0, withType: .file) }

    // Process and copy each file
    for file in files {
      let result = processAndCopyFile(
        file,
        from: templateDirectory,
        to: outputDirectory,
        packageName: packageName,
        identifier: identifier
      )

      if case .failure = result {
        return result
      }
    }

    if templateDirectory.lastPathComponent != "Base" {
      log.info("Updating indentation to '\(indentationStyle.defaultValueDescription)'")
    }
    return updateIndentationStyle(in: outputDirectory, from: .tabs, to: indentationStyle)
  }

  /// Updates the indentation style of all files within the given folder with another indentation style.
  ///
  /// This function may break code it touches if the original indentation sequence (``IndentationStyle/string``) occurs in any non-indentation
  /// contexts. Therefore it is safest to use this function on directories whose original indentation style is ``IndentationStyle/tabs``.
  /// - Parameters:
  ///   - directory: The directory to update the indentation style in.
  ///   - indentationStyle: The new indentation style.
  /// - Returns: If an error occurs, a failure is returned.
  static func updateIndentationStyle(
    in directory: URL,
    from originalStyle: IndentationStyle,
    to newStyle: IndentationStyle
  ) -> Result<Void, TemplaterError> {
    if originalStyle == newStyle {
      return .success()
    }

    guard
      let enumerator = FileManager.default.enumerator(
        at: directory, includingPropertiesForKeys: nil)
    else {
      return .failure(
        .failedToUpdateIndentationStyle(
          directory: directory, TemplaterError.failedToEnumerateOutputFiles))
    }

    do {
      for case let file as URL in enumerator {
        if FileManager.default.itemExists(at: file, withType: .file) {
          var contents = try String(contentsOf: file)
          contents = contents.replacingOccurrences(of: originalStyle.string, with: newStyle.string)
          try contents.write(to: file, atomically: false, encoding: .utf8)
        }
      }
    } catch {
      return .failure(.failedToUpdateIndentationStyle(directory: directory, error))
    }

    return .success()
  }

  // MARK: Private methods

  /// Attempts to delete the output directory after a failed attempt to create a package.
  /// - Parameter outputDirectory: The output directory to remove.
  private static func attemptCleanup(_ outputDirectory: URL) {
    try? FileManager.default.removeItem(at: outputDirectory)
  }

  /// Processes a template file (replacing occurences of `{{variable}}` with the variable's values) and then copies it to a destination directory.
  ///
  /// Currently only the `PACKAGE` and `IDENTIFIER` variables are available.
  /// - Parameters:
  ///   - file: The template file.
  ///   - templateDirectory: The directory of the template that the file is from.
  ///   - outputDirectory: The directory to output the file to (the file gets copied to the same relative location as in `templateDirectory`).
  ///   - packageName: The name of the package.
  ///   - identifier: The package's identifier (e.g. 'com.example.ExampleApp').
  /// - Returns: A failure if file processing or copying fails.
  private static func processAndCopyFile(
    _ file: URL,
    from templateDirectory: URL,
    to outputDirectory: URL,
    packageName: String,
    identifier: String
  ) -> Result<Void, TemplaterError> {
    let variables: [String: String] = [
      "PACKAGE": packageName,
      "IDENTIFIER": identifier,
    ]

    // Read the file's contents
    let contents = String.read(from: file).mapError { error in
      TemplaterError.failedToReadFile(
        template: templateDirectory.lastPathComponent,
        file: file,
        error
      )
    }
    guard case .success(var contents) = contents else {
      return contents.replacingSuccessValue(with: ())
    }

    // If the file is a template, replace all instances of `{{variable}}` with the variable's value
    var file = file
    if file.pathExtension == "template" {
      for (variable, value) in variables {
        contents = contents.replacingOccurrences(of: "{{\(variable)}}", with: value)
      }
      file = file.deletingPathExtension()
    }

    // Get the file's relative path (compared to the template root directory)
    var relativePath = file.path(relativeTo: templateDirectory)

    // Compute the output directory, replacing occurrences of `{{variable}}` in the original path with the variable's value
    for (variable, value) in variables {
      relativePath = relativePath.replacingOccurrences(of: "{{\(variable)}}", with: value)
    }

    // Write to the output file
    let outputFile = outputDirectory.appendingPathComponent(relativePath)
    _ = FileManager.default.createDirectory(at: outputFile.deletingLastPathComponent())
    return contents.write(to: outputFile).mapError { error in
      .failedToWriteToOutputFile(file: file, error)
    }
  }
}
