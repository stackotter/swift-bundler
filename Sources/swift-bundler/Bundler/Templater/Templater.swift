import Foundation
import Version

/// A utility for creating packages from package templates.
enum Templater {
  /// The repository of default templates.
  static let defaultTemplateRepository = "https://github.com/stackotter/swift-bundler-templates"

  /// Creates a package from the specified template from the default template repository.
  ///
  /// Downloads the default template repository if it hasn't already been downloaded.
  /// - Parameters:
  ///   - outputDirectory: The directory to create the package in.
  ///   - template: The template to use to create the package.
  ///   - packageName: The name of the package.
  ///   - forceCreation: If `true`, the package will be created even if the selected template doesn't support the user's system and Swift version.
  ///   - indentationStyle: The indentation style to use.
  /// - Returns: A failure if package creation fails.
  static func createPackage(
    in outputDirectory: URL,
    from template: String,
    packageName: String,
    forceCreation: Bool,
    indentationStyle: IndentationStyle
  ) -> Result<Void, TemplaterError> {
    if FileManager.default.fileExists(atPath: outputDirectory.path) {
      return .failure(.packageDirectoryAlreadyExists(outputDirectory))
    }

    if template == "Skeleton" {
      return createSkeletonPackage(in: outputDirectory, packageName: packageName, indentationStyle: indentationStyle)
    }

    // Get the default templates directory (and download if not present), and then create the package
    return getDefaultTemplatesDirectory(downloadIfNecessary: true)
      .flatMap { templatesDirectory in
        createPackage(
          in: outputDirectory,
          from: template,
          in: templatesDirectory,
          packageName: packageName,
          forceCreation: forceCreation,
          indentationStyle: indentationStyle)
      }
  }

  /// Creates a package from the specified template from the specified template repository.
  /// - Parameters:
  ///   - outputDirectory: The directory to create the package in.
  ///   - template: The template to use to create the package.
  ///   - templatesDirectory: The directory containing the template to use.
  ///   - packageName: The name of the package.
  ///   - forceCreation: If `true`, the package will be created even if the selected template doesn't support the user's system and Swift version.
  ///   - indentationStyle: The indentation style to use.
  /// - Returns: A failure if package creation fails.
  static func createPackage(
    in outputDirectory: URL,
    from template: String,
    in templatesDirectory: URL,
    packageName: String,
    forceCreation: Bool,
    indentationStyle: IndentationStyle
  ) -> Result<Void, TemplaterError> {
    if FileManager.default.fileExists(atPath: outputDirectory.path) {
      return .failure(.packageDirectoryAlreadyExists(outputDirectory))
    }

    // The `Base` template should not be used to create packages directly
    guard template != "Base" else {
      return .failure(.cannotCreatePackageFromBaseTemplate)
    }

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

    // Verify that the current OS and Swift version are supported
    if !forceCreation {
      #if os(macOS)
      if !manifest.platforms.contains("macOS") {
        return .failure(.templateDoesNotSupportCurrentPlatform(template: template, platform: "macOS", supportedPlatforms: manifest.platforms))
      }
      #else
      return .failure(.templateDoesNotSupportCurrentPlatform(template: template, platform: "unknown", supportedPlatforms: manifest.platforms))
      #endif

      switch SwiftPackageManager.getSwiftVersion() {
        case .success(let version):
          if version < manifest.minimumSwiftVersion {
            return .failure(.templateDoesNotSupportSwiftVersion(template: template, version: version, minimumSupportedVersion: manifest.minimumSwiftVersion))
          }
        case .failure(let error):
          return .failure(.failedToCheckSwiftVersion(error))
      }
    }

    // Create the output directory
    do {
      try FileManager.default.createDirectory(at: outputDirectory)
    } catch {
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
        indentationStyle: .tabs)
      if case .failure = result {
        attemptCleanup(outputDirectory)
        return result
      }
    }

    // Apply the template
    return applyTemplate(
      templateDirectory,
      to: outputDirectory,
      packageName: packageName,
      indentationStyle: indentationStyle
    ).mapError { error in
      attemptCleanup(outputDirectory)
      return error
    }
  }

  /// Gets the default templates directory.
  /// - Parameter downloadIfNecessary: If `true` the default templates repository is downloaded if the templates directory doesn't exist.
  /// - Returns: The default templates directory, or a failure if the templates directory doesn't exist and couldn't be downloaded.
  static func getDefaultTemplatesDirectory(downloadIfNecessary: Bool) -> Result<URL, TemplaterError> {
    // Get the templates directory
    let templatesDirectory: URL
    switch Bundler.getApplicationSupportDirectory() {
      case let .success(applicationSupport):
        templatesDirectory = applicationSupport.appendingPathComponent("templates")
      case let .failure(error):
        return .failure(.failedToGetApplicationSupportDirectory(error))
    }

    // Download the templates if they don't exist
    if !FileManager.default.itemExists(at: templatesDirectory, withType: .directory) {
      let result = downloadDefaultTemplates(into: templatesDirectory)
      if case let .failure(error) = result {
        return .failure(error)
      }
    }

    return .success(templatesDirectory)
  }

  /// Updates the default templates to the latest version from GitHub.
  /// - Returns: A failure if updating fails.
  static func updateTemplates() -> Result<Void, TemplaterError> {
    return getDefaultTemplatesDirectory(downloadIfNecessary: false)
      .flatMap { templatesDirectory in
        if FileManager.default.itemExists(at: templatesDirectory, withType: .directory) {
          let process = Process.create(
            "/usr/bin/git",
            arguments: ["pull"],
            directory: templatesDirectory)
          if case let .failure(error) = process.runAndWait() {
            return .failure(.failedToPullLatestTemplates(error))
          }
          return .success()
        } else {
          return downloadDefaultTemplates(into: templatesDirectory)
        }
      }
  }

  /// Gets the list of available templates from the default templates directory.
  /// - Returns: The available templates, or an error if template enumeration fails.
  static func enumerateTemplates() -> Result<[Template], TemplaterError> {
    return getDefaultTemplatesDirectory(downloadIfNecessary: true)
      .flatMap { templatesDirectory in
        enumerateTemplates(in: templatesDirectory)
      }
      .map { templates in
        var templates = templates

        // Add the autogenerated skeleton template
        templates.insert(Template(
          name: "Skeleton",
          manifest: TemplateManifest(
            description: "The bare minimum package with no default UI.",
            platforms: ["macOS", "Linux"],
            minimumSwiftVersion: Version(3, 0, 0)
          )
        ), at: 0)

        return templates
      }
  }

  /// Gets the list of available templates from a templates directory.
  /// - Parameter templatesDirectory: The directory to search for templates in.
  /// - Returns: The available templates, or an error if template enumeration fails.
  static func enumerateTemplates(in templatesDirectory: URL) -> Result<[Template], TemplaterError> {
    do {
      let contents = try FileManager.default.contentsOfDirectory(at: templatesDirectory, includingPropertiesForKeys: nil, options: [])
      var templates: [Template] = []

      // Enumerate templates
      for directory in contents {
        guard FileManager.default.itemExists(at: directory, withType: .directory) else {
          continue
        }

        let templateName = directory.lastPathComponent

        // Skip `Base` template and `.git` directory
        guard templateName != "Base" && templateName != ".git" else {
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
  static func downloadDefaultTemplates(into directory: URL) -> Result<Void, TemplaterError> {
    log.info("Downloading default templates (\(defaultTemplateRepository))")

    // Remove the directory if it already exists
    try? FileManager.default.removeItem(at: directory)

    // Clone the templates repository
    let process = Process.create(
      "/usr/bin/git",
      arguments: [
        "clone", "\(defaultTemplateRepository)",
        directory.path
      ])

    return process.runAndWait()
      .mapError { error in
        .failedToCloneTemplateRepository(error)
      }
  }

  /// Creates a package for the 'Skeleton' template.
  ///
  /// It just generates a package using the SwiftPM cli and then adds a basic `Bundler.toml` configuration file.
  /// - Parameters:
  ///   - directory: The directory create the package in.
  ///   - packageName: The name of the package.
  ///   - indentationStyle: The style of indentation to use.
  /// - Returns: A failure if package creation fails.
  static func createSkeletonPackage(in directory: URL, packageName: String, indentationStyle: IndentationStyle) -> Result<Void, TemplaterError> {
    log.info("Creating skeleton package")

    return SwiftPackageManager.createPackage(in: directory, name: packageName)
      .mapError { error -> TemplaterError in
        .failedToCreateSkeletonPackage(error)
      }
      .flatMap { _ in
        log.info("Updating indentation to '\(indentationStyle.defaultValueDescription)'")
        return updateIndentationStyle(in: directory, from: IndentationStyle.spaces(4), to: indentationStyle)
      }
      .mapError { error -> TemplaterError in
        attemptCleanup(directory)
        return error
      }
  }

  /// Applies a template to a directory (processes and copies the template's files).
  /// - Parameters:
  ///   - templateDirectory: The template's directory.
  ///   - outputDirectory: The directory to copy the resulting files to.
  ///   - packageName: The name of the package.
  ///   - indentationStyle: The style of indentation to use.
  /// - Returns: A failure if template application fails.
  static func applyTemplate(
    _ templateDirectory: URL,
    to outputDirectory: URL,
    packageName: String,
    indentationStyle: IndentationStyle
  ) -> Result<Void, TemplaterError> {
    log.info("Applying '\(templateDirectory.lastPathComponent)' template")

    guard let enumerator = FileManager.default.enumerator(at: templateDirectory, includingPropertiesForKeys: nil) else {
      return .failure(.failedToEnumerateTemplateContents(template: templateDirectory.lastPathComponent))
    }

    // Enumerate the template's files
    let excluded = Set(["Template.toml"])
    let files = enumerator
      .compactMap { $0 as? URL }
      .filter { !excluded.contains($0.lastPathComponent) }
      .filter { FileManager.default.itemExists(at: $0, withType: .file) }

    // Process and copy each file
    for file in files {
      let result = processAndCopyFile(
        file,
        from: templateDirectory,
        to: outputDirectory,
        packageName: packageName)

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

    guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else {
      return .failure(.failedToUpdateIndentationStyle(directory: directory, TemplaterError.failedToEnumerateOutputFiles))
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

  /// Processes a template file (replacing occurences of `{{PACKAGE}}` with the package name) and then copies it to a destination directory.
  /// - Parameters:
  ///   - file: The template file.
  ///   - templateDirectory: The directory of the template that the file is from.
  ///   - outputDirectory: The directory to output the file to (the file gets copied to the same relative location as in `templateDirectory`).
  ///   - packageName: The name of the package.
  /// - Returns: A failure if file processing or copying fails.
  private static func processAndCopyFile(
    _ file: URL,
    from templateDirectory: URL,
    to outputDirectory: URL,
    packageName: String
  ) -> Result<Void, TemplaterError> {
    // Read the file's contents
    var contents: String
    do {
      contents = try String(contentsOf: file)
    } catch {
      return .failure(.failedToReadFile(template: templateDirectory.lastPathComponent, file: file, error))
    }

    var file = file

    // If the file is a template, replace all instances of `{{PACKAGE}}` with the package's name
    if file.pathExtension == "template" {
      contents = contents.replacingOccurrences(of: "{{PACKAGE}}", with: packageName)
      file = file.deletingPathExtension()
    }

    // Get the file's relative path (compared to the template root directory)
    guard var relativePath = file.relativePath(from: templateDirectory) else {
      return .failure(.failedToGetRelativePath(file: file, base: templateDirectory))
    }

    // Compute the output directory, replacing occurrences of `{{PACKAGE}}` in the original path with the package's name
    relativePath = relativePath
      .replacingOccurrences(of: "{{PACKAGE}}", with: packageName)
    let outputFile = outputDirectory.appendingPathComponent(relativePath)

    // Write to the output file
    try? FileManager.default.createDirectory(at: outputFile.deletingLastPathComponent())
    do {
      try contents.write(to: outputFile, atomically: false, encoding: .utf8)
    } catch {
      return .failure(.failedToWriteToOutputFile(file: file, error))
    }

    return .success()
  }
}
