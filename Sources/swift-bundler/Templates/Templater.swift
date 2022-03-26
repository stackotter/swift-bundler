import Foundation

enum TemplaterError: LocalizedError {
  case failedToCloneTemplateRepository(ProcessError)
  case failedToGetApplicationSupportDirectory(Error)
  case cannotCreatePackageFromBaseTemplate
  case noSuchTemplate(String)
  case failedToCreateOutputDirectory(Error)
  case failedToCopyBaseTemplate(Error)
  case failedToDecodeTemplateManifest(Error)
  case failedToReadTemplateManifest(Error)
  case templateDoesNotSupportCurrentPlatform(template: String, platform: String, supportedPlatforms: [String])
  case failedToEnumerateTemplateContents(template: String)
  case failedToReadTemplateFile(URL, Error)
  case fileNotInsideTemplateDirectory(URL)
  case failedToGetRelativePath(from: URL, to: URL)
  case failedToWriteToOutputFile(Error)
  case failedToCreateSkeletonPackage(Error)
  case failedToEnumerateTemplates(Error)
  case failedToPullLatestTemplates(ProcessError)
}

enum Templater {
  static func createPackage(
    in directory: URL,
    from template: String,
    targetName: String,
    forceCreation: Bool
  ) -> Result<Void, TemplaterError> {
    guard template != "Skeleton" else {
      return createSkeletonPackage(in: directory, targetName: targetName)
    }
    
    // Get the default templates directory (and download if not present), and then create the package
    return getDefaultTemplatesDirectory(downloadIfNecessary: true)
      .flatMap { templatesDirectory in
        createPackage(
          in: directory,
          from: template,
          in: templatesDirectory,
          targetName: targetName,
          forceCreation: forceCreation)
      }
  }
  
  static func createPackage(
    in outputDirectory: URL,
    from template: String,
    in templatesDirectory: URL,
    targetName: String,
    forceCreation: Bool
  ) -> Result<Void, TemplaterError> {
    // The `Base` template should not be used to create packages directly
    guard template != "Base" else {
      return .failure(.cannotCreatePackageFromBaseTemplate)
    }
    
    // Check that the template exists
    let templateDirectory = templatesDirectory.appendingPathComponent(template)
    guard FileManager.default.itemExists(at: templateDirectory, withType: .directory) else {
      return .failure(.noSuchTemplate(template))
    }
    
    // Create the output directory
    do {
      try FileManager.default.createDirectory(at: outputDirectory)
    } catch {
      return .failure(.failedToCreateOutputDirectory(error))
    }
    
    // Load the template manifest
    let manifestFile = templateDirectory.appendingPathComponent("Template.toml")
    let manifest: TemplateManifest
    switch TemplateManifest.load(from: manifestFile) {
      case let .success(templateManifest):
        manifest = templateManifest
      case let .failure(error):
        return .failure(error)
    }
    
    // Verify that the current OS is supported
    if !forceCreation {
      #if os(macOS)
      if !manifest.platforms.contains("macOS") {
        // TODO: Provide this message in the localized description for the error
        print("This template does not support the 'macOS' platform, provide the `-f` option to override")
        return .failure(.templateDoesNotSupportCurrentPlatform(template: template, platform: "macOS", supportedPlatforms: manifest.platforms))
      }
      #else
      // TODO: Provide this message in the localized description for the error
      print("This template does not support the 'unknown' platform, provide the `-f` option to override")
      return .failure(.templateDoesNotSupportCurrentPlatform(template: template, platform: "unknown", supportedPlatforms: manifest.platforms))
      #endif
    }
    
    // Apply the base template first if it exists
    let baseTemplate = templatesDirectory.appendingPathComponent("Base")
    if FileManager.default.itemExists(at: baseTemplate, withType: .directory) {
      let result = applyTemplate(baseTemplate, to: outputDirectory, targetName: targetName)
      if case .failure = result {
        return result
      }
    }
    
    // Apply the template
    return applyTemplate(templateDirectory, to: outputDirectory, targetName: targetName)
  }
  
  static func applyTemplate(_ templateDirectory: URL, to outputDirectory: URL, targetName: String) -> Result<Void, TemplaterError> {
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
      let result = processAndCopyFile(file, from: templateDirectory, to: outputDirectory, targetName: targetName)
      if case .failure = result {
        return result
      }
    }
    
    return .success()
  }
  
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
      let result = downloadTemplates(into: templatesDirectory)
      if case let .failure(error) = result {
        return .failure(error)
      }
    }
    
    return .success(templatesDirectory)
  }
  
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
          return downloadTemplates(into: templatesDirectory)
        }
      }
  }
  
  static func listTemplates() -> Result<[Template], TemplaterError> {
    return getDefaultTemplatesDirectory(downloadIfNecessary: true)
      .flatMap { templatesDirectory in
        do {
          let contents = try FileManager.default.contentsOfDirectory(at: templatesDirectory, includingPropertiesForKeys: nil, options: [])
          var templates: [Template] = []
          
          // Add the autogenerated skeleton template
          templates.append(Template(
            name: "Skeleton",
            manifest: TemplateManifest(
              description: "The bare minimum package with no default UI.",
              platforms: ["macOS", "Linux"],
              minimumSwiftVersion: "5"
            )
          ))
          
          // Enumerate templates
          for directory in contents {
            guard FileManager.default.itemExists(at: directory, withType: .directory) else {
              continue
            }
            
            // Skip `Base` template and `.git` directory
            guard directory.lastPathComponent != "Base" && directory.lastPathComponent != ".git" else {
              continue
            }
            
            // Load the template manifest file
            let manifestFile = directory.appendingPathComponent("Template.toml")
            let manifest: TemplateManifest
            switch TemplateManifest.load(from: manifestFile) {
              case let .success(templateManifest):
                manifest = templateManifest
              case let .failure(error):
                return .failure(error)
            }
            
            let template = Template(name: directory.lastPathComponent, manifest: manifest)
            templates.append(template)
          }
          
          return .success(templates)
        } catch {
          return .failure(.failedToEnumerateTemplates(error))
        }
      }
  }
  
  static func createSkeletonPackage(in directory: URL, targetName: String) -> Result<Void, TemplaterError> {
    return SwiftPackageManager.createPackage(in: directory, name: targetName)
      .mapError { error in
        .failedToCreateSkeletonPackage(error)
      }
  }
  
  /// Downloads the default template repository.
  /// - Parameter directory: The directory to clone the template repository in.
  static func downloadTemplates(into directory: URL) -> Result<Void, TemplaterError> {
    log.info("Downloading default templates (https://github.com/stackotter/swift-bundler-templates)")
    
    // Remove the directory if it already exists
    try? FileManager.default.removeItem(at: directory)
    
    // Clone the templates repository
    let process = Process.create(
      "/usr/bin/git",
      arguments: [
        "clone", "https://github.com/stackotter/swift-bundler-templates",
        directory.path
      ])
    
    return process.runAndWait()
      .mapError { error in
        return .failedToCloneTemplateRepository(error)
      }
  }
  
  private static func processAndCopyFile(
    _ file: URL,
    from templateDirectory: URL,
    to outputDirectory: URL,
    targetName: String
  ) -> Result<Void, TemplaterError> {
    // Read the file's contents
    var contents: String
    do {
      contents = try String(contentsOf: file)
    } catch {
      return .failure(.failedToReadTemplateFile(file, error))
    }
    
    var file = file
    
    // If the file is a template, replace all instances of `{{TARGET}}` with the package's name
    if file.pathExtension == "template" {
      contents = contents.replacingOccurrences(of: "{{TARGET}}", with: targetName)
      file = file.deletingPathExtension()
    }
    
    // Get the file's relative path (compared to the template root directory)
    guard var relativePath = file.relativePath(from: templateDirectory) else {
      return .failure(.failedToGetRelativePath(from: templateDirectory, to: file))
    }
    
    // Compute the output directory, replacing occurrences of `{{TARGET}}` in the original path with the package's name
    relativePath = relativePath
      .replacingOccurrences(of: "{{TARGET}}", with: targetName)
    let outputFile = outputDirectory.appendingPathComponent(relativePath)
    
    // Write to the output file
    try? FileManager.default.createDirectory(at: outputFile.deletingLastPathComponent())
    do {
      try contents.write(to: outputFile, atomically: false, encoding: .utf8)
    } catch {
      return .failure(.failedToWriteToOutputFile(error))
    }
    
    return .success()
  }
}
