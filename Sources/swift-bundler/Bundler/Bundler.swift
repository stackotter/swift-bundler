import Foundation

enum BundlerError: LocalizedError {
  case failedToRunSwiftBuild(Error)
  case failedToCreateAppBundleDirectoryStructure(Error)
  case failedToCreatePkgInfo(Error)
  case failedToCreateInfoPlist(PlistError)
  case failedToCopyExecutable(Error)
  case failedToCreateIcon(IconError)
  case failedToCopyICNS(Error)
  case failedToRunExecutable(ProcessError)
  case failedToRunPrebuildScript(ScriptRunnerError)
  case failedToRunPostbuildScript(ScriptRunnerError)
  case failedtoEnumerateProductsDirectory
  case failedToCopyBundle(Error)
  case failedToCreateBundleDirectory(Error)
  case failedToCreateResourceBundleInfoPlist(PlistError)
  case failedToCopyResource(String, bundle: String)
  case failedToCreateEnumerator
  case failedToEnumerateResourceBundleContents(Error)
  case failedToCreateMetalCompilationTempDirectory(Error)
  case failedToCompileMetalShader(String, ProcessError)
  case failedToCreateMetalArchive(ProcessError)
  case failedToCreateMetalLibrary(ProcessError)
  case failedToDeleteShaderSource(String, Error)
  case failedToEnumerateResourceBundles(Error)
}

struct Bundler {
  var context: Context
  
  var appBundle: URL {
    context.outputDirectory.appendingPathComponent("\(context.appName).app")
  }
  
  var appExecutable: URL {
    appBundle.appendingPathComponent("Contents/MacOS/\(context.appName)")
  }
  
  var appResources: URL {
    appBundle.appendingPathComponent("Contents/Resources")
  }
  
  var isXcodeBuild: Bool {
    false
  }
  
  struct Context {
    var appConfiguration: AppConfiguration
    var buildConfiguration: BuildConfiguration
    var packageDirectory: URL
    var productsDirectory: URL
    var outputDirectory: URL
    var appName: String
    var universal: Bool
  }
  
  enum BuildConfiguration: String {
    case debug
    case release
  }
  
  /// Creates a new bundler for the given context.
  /// - Parameter context: The context of the app to bundle.
  init(_ context: Context) {
    self.context = context
  }
  
  /// Runs the app's prebuild script.
  /// - Returns: Returns an error if the script exists and fails to run.
  func prebuild() -> Result<Void, BundlerError> {
    log.info("Running prebuild script")
    let scriptRunner = ScriptRunner(context.packageDirectory)
    return scriptRunner.runPrebuildScriptIfPresent()
      .mapError { error in
          .failedToRunPrebuildScript(error)
      }
  }
  
  /// Builds the app's executable.
  func build() -> Result<Void, BundlerError> {
    let buildConfiguration = context.buildConfiguration.rawValue
    log.info("Starting \(buildConfiguration) build")
    
    var arguments = [
      "build",
      "-c", buildConfiguration,
      "--target", context.appConfiguration.target]
    if context.universal {
      arguments += ["--arch", "arm64", "--arch", "x86_64"]
    }
    
    let process = Process.create("/usr/bin/swift", arguments: arguments, directory: context.packageDirectory)
    return process.runAndWait()
      .mapError { error in
        .failedToRunSwiftBuild(error)
      }
  }
  
  /// Bundles the built executable into a macOS app.
  /// - Returns: If a failure occurs, it is returned.
  func bundle() -> Result<Void, BundlerError> {
    let executableArtifact = context.productsDirectory.appendingPathComponent(context.appConfiguration.target)
    let appContents = appBundle.appendingPathComponent("Contents")
    let appResources = appContents.appendingPathComponent("Resources")
    
    let bundleApp = flatten(
      { createAppDirectoryStructure(at: appBundle) },
      { copyExecutable(at: executableArtifact, to: appExecutable) },
      { createMetadataFiles(at: appContents) },
      { createAppIcon(appResources) },
      copyResourceBundles)
    
    return bundleApp()
  }
  
  /// Runs the app's postbuild script.
  /// - Returns: Returns an error if the script exists and fails to run.
  func postbuild() -> Result<Void, BundlerError> {
    log.info("Running postbuild script")
    let scriptRunner = ScriptRunner(context.packageDirectory)
    return scriptRunner.runPostbuildScriptIfPresent()
      .mapError { error in
        .failedToRunPostbuildScript(error)
      }
  }
  
  /// Runs the app (``build()`` and ``bundle()`` must be called first.
  /// - Returns: Returns a failure if the app fails to run.
  func run() -> Result<Void, BundlerError> {
    log.info("Running '\(context.appName).app'")
    let process = Process.create(appExecutable.path)
    return process.runAndWait()
      .mapError { error in
        .failedToRunExecutable(error)
      }
  }
  
  // MARK: Private methods
  
  /// Creates the following directory structure for the app:
  /// - `AppName.app`
  ///   - `Contents`
  ///     - `MacOS`
  ///
  /// - Parameter appBundleDirectory: The directory for the app (should be of the form `/path/to/AppName.app`).
  private func createAppDirectoryStructure(at appBundleDirectory: URL) -> Result<Void, BundlerError> {
    log.info("Creating '\(context.appName).app'")
    let fileManager = FileManager.default
    
    let appContents = appBundleDirectory.appendingPathComponent("Contents")
    let appResources = appContents.appendingPathComponent("Resources")
    let appMacOS = appContents.appendingPathComponent("MacOS")
    
    do {
      if fileManager.itemExists(at: appBundle, withType: .directory) {
        try fileManager.removeItem(at: appBundle)
      }
      try fileManager.createDirectory(at: appResources)
      try fileManager.createDirectory(at: appMacOS)
      return .success()
    } catch {
      return .failure(.failedToCreateAppBundleDirectoryStructure(error))
    }
  }
  
  /// Copies the built executable into the app bundle.
  /// - Parameters:
  ///   - source: The location of the built executable.
  ///   - destination: The target location of the built executable (the file not the directory).
  private func copyExecutable(at source: URL, to destination: URL) -> Result<Void, BundlerError> {
    log.info("Copying executable")
    do {
      try FileManager.default.copyItem(at: source, to: destination)
      return .success()
    } catch {
      return .failure(.failedToCopyExecutable(error))
    }
  }
  
  /// Creates an app's `PkgInfo` and `Info.plist` files.
  /// - Parameters:
  ///   - appContentsDirectory: The app's `Contents` directory.
  ///   - context: The context to create the `Info.plist` within.
  private func createMetadataFiles(at appContentsDirectory: URL) -> Result<Void, BundlerError> {
    log.info("Creating 'PkgInfo'")
    do {
      let pkgInfoFile = appContentsDirectory.appendingPathComponent("PkgInfo")
      var pkgInfoBytes: [UInt8] = [0x41, 0x50, 0x50, 0x4c, 0x3f, 0x3f, 0x3f, 0x3f]
      let pkgInfoData = Data(bytes: &pkgInfoBytes, count: pkgInfoBytes.count)
      try pkgInfoData.write(to: pkgInfoFile)
    } catch {
      return .failure(.failedToCreatePkgInfo(error))
    }
    
    log.info("Creating 'Info.plist'")
    let infoPlistFile = appContentsDirectory.appendingPathComponent("Info.plist")
    let plistCreator = PlistCreator()
    return plistCreator.createAppInfoPlist(at: infoPlistFile, appName: context.appName, appConfiguration: context.appConfiguration)
      .mapError { error in
        .failedToCreateInfoPlist(error)
      }
  }
  
  /// Copies `AppIcon.icns` into the app bundle if present. Alternatively, it creates the app's `AppIcon.icns` from a png if an `Icon1024x1024.png` is present.
  ///
  /// `AppIcon.icns` takes precendence over `Icon1024x1024.png`.
  /// - Parameter appResources: The app's `Resources` directory.
  /// - Throws: If `Icon1024x1024.png` exists and there is an error while converting it to `icns`, an error is thrown.
  private func createAppIcon(_ appResources: URL) -> Result<Void, BundlerError> {
    // Copy `AppIcon.icns` if present
    let icnsFile = context.packageDirectory.appendingPathComponent("AppIcon.icns")
    if FileManager.default.itemExists(at: icnsFile, withType: .file) {
      log.info("Copying 'AppIcon.icns'")
      do {
        try FileManager.default.copyItem(at: icnsFile, to: appResources.appendingPathComponent("AppIcon.icns"))
        return .success()
      } catch {
        return .failure(.failedToCopyICNS(error))
      }
    }
    
    // Create `AppIcon.icns` from `Icon1024x1024.png` if present
    let iconFile = context.packageDirectory.appendingPathComponent("Icon1024x1024.png")
    if FileManager.default.itemExists(at: iconFile, withType: .file) {
      log.info("Creating 'AppIcon.icns' from 'Icon1024x1024.png'")
      return IconSetCreator.createIcns(from: iconFile, outputDirectory: appResources)
        .mapError { error in
          .failedToCreateIcon(error)
        }
    }
    
    return .success()
  }
  
  /// Copies the resource bundles present in the products directory into ``appResources``.
  ///
  /// If the bundles were built by SwiftPM, they will get fixed up to be consistent with bundles built by Xcode.
  private func copyResourceBundles() -> Result<Void, BundlerError> {
    let contents: [URL]
    do {
      contents = try FileManager.default.contentsOfDirectory(at: context.productsDirectory, includingPropertiesForKeys: nil, options: [])
    } catch {
      return .failure(.failedToEnumerateResourceBundles(error))
    }
    
    for file in contents where file.pathExtension == "bundle" {
      guard FileManager.default.itemExists(at: file, withType: .directory) else {
        continue
      }
      
      let result = copyResourceBundle(file, to: appResources)
      if case .failure(_) = result {
        return result
      }
    }
    
    return .success()
  }
  
  /// Copies the specified resource bundle into a destination directory.
  ///
  /// If the bundle was built by SwiftPM, it will get fixed up to be consistent with bundles built by Xcode.
  /// - Parameters:
  ///   - bundle: The bundle to copy (and fix if necessary).
  ///   - destination: The directory to copy the bundle into.
  private func copyResourceBundle(_ bundle: URL, to destination: URL) -> Result<Void, BundlerError> {
    log.info("Copying resource bundle `\(bundle.lastPathComponent)`")
    let destinationBundle = destination.appendingPathComponent(bundle.lastPathComponent)
    if isXcodeBuild {
      // If it's a bundle generated by Xcode, no extra processing is required
      do {
        try FileManager.default.copyItem(at: bundle, to: destinationBundle)
        return .success()
      } catch {
        return .failure(.failedToCopyBundle(error))
      }
    } else {
      let destinationBundleResources = destinationBundle
        .appendingPathComponent("Contents")
        .appendingPathComponent("Resources")
      
      // If it's a bundle generated by SwiftPM, it's gonna need a bit of fixing
      let copyBundle = flatten(
        { createResourceBundleDirectoryStructure(at: destinationBundle) },
        { createResourceBundleInfoPlist(in: destinationBundle) },
        { copyResources(from: bundle, to: destinationBundleResources) },
        { compileMetalShaders(in: destinationBundleResources, keepSources: false) })
      
      return copyBundle()
    }
  }
  
  /// Creates the following structure for the specified resource bundle directory:
  ///
  /// - `Contents`
  ///   - `Info.plist`
  ///   - `Resources`
  /// - Parameter bundle: The bundle to create.
  private func createResourceBundleDirectoryStructure(at bundle: URL) -> Result<Void, BundlerError> {
    let bundleContents = bundle.appendingPathComponent("Contents")
    let bundleResources = bundleContents.appendingPathComponent("Resources")
    
    do {
      try FileManager.default.createDirectory(at: bundleResources)
    } catch {
      return .failure(.failedToCreateBundleDirectory(error))
    }
    
    return .success()
  }
  
  /// Creates the `Info.plist` file for a resource bundle.
  /// - Parameter bundle: The bundle to create the `Info.plist` file for.
  private func createResourceBundleInfoPlist(in bundle: URL) -> Result<Void, BundlerError> {
    let bundleName = bundle.deletingPathExtension().lastPathComponent
    let infoPlist = bundle
      .appendingPathComponent("Contents")
      .appendingPathComponent("Info.plist")
    
    let plistCreator = PlistCreator()
    let result = plistCreator.createResourceBundleInfoPlist(at: infoPlist, bundleName: bundleName, appConfiguration: context.appConfiguration)
    if case let .failure(error) = result {
      return .failure(.failedToCreateResourceBundleInfoPlist(error))
    }
    
    return .success()
  }
  
  /// Copies the resources from a source directory to a destination directory.
  ///
  /// If any of the resources are metal shader sources, they get compiled into a `default.metallib`.
  /// After compilation, the sources are deleted.
  /// - Parameters:
  ///   - source: The source directory.
  ///   - destination: The destination directory.
  private func copyResources(from source: URL, to destination: URL) -> Result<Void, BundlerError> {
    let contents: [URL]
    do {
      contents = try FileManager.default.contentsOfDirectory(at: source, includingPropertiesForKeys: nil, options: [])
    } catch {
      return .failure(.failedToEnumerateResourceBundleContents(error))
    }
    
    for file in contents {
      do {
        try FileManager.default.copyItem(
          at: file,
          to: destination.appendingPathComponent(file.lastPathComponent))
      } catch {
        return .failure(.failedToCopyResource(file.lastPathComponent, bundle: source.lastPathComponent))
      }
    }
    
    return .success()
  }
  
  /// Compiles any metal shaders present in a directory into a `default.metallib` file (in the same directory).
  /// - Parameters:
  ///   - directory: The directory to compile shaders from.
  ///   - keepSources: If `false`, the sources will get deleted after compilation.
  private func compileMetalShaders(in directory: URL, keepSources: Bool) -> Result<Void, BundlerError> {
    guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: []) else {
      return .failure(.failedToCreateEnumerator)
    }
    
    var shaderSources: [URL] = []
    for case let file as URL in enumerator where file.pathExtension == "metal" {
      shaderSources.append(file)
    }
    
    guard !shaderSources.isEmpty else {
      return .success()
    }
    
    log.info("Compiling metal shaders")
    
    return compileMetalShaders(shaderSources, destination: directory)
      .flatMap { _ in
        guard !keepSources else {
          return .success()
        }
        
        for source in shaderSources {
          do {
            try FileManager.default.removeItem(at: source)
          } catch {
            return .failure(.failedToDeleteShaderSource(source.lastPathComponent, error))
          }
        }
        return .success()
      }
  }
  
  /// Compiles a list of metal source files.
  /// - Parameters:
  ///   - sources: The source files to comile.
  ///   - destination: The directory to output the `default.metallib` to.
  private func compileMetalShaders(_ sources: [URL], destination: URL) -> Result<Void, BundlerError> {
    // Create a temporary directory for compilation
    let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("metal-compilation-\(UUID().uuidString)")
    do {
      try FileManager.default.createDirectory(at: tempDirectory)
    } catch {
      return .failure(.failedToCreateMetalCompilationTempDirectory(error))
    }
    
    // Compile the shaders into `.air` files
    for shaderSource in sources {
      let process = Process.create(
        "/usr/bin/xcrun",
        arguments: [
          "-sdk", "macosx", "metal",
          "-c", shaderSource.path,
          "-o", shaderSource.deletingPathExtension().appendingPathExtension("air").lastPathComponent
        ],
        directory: tempDirectory)
      let result = process.runAndWait()
      if case let .failure(error) = result {
        return .failure(.failedToCompileMetalShader(shaderSource.lastPathComponent, error))
      }
    }
    
    // Combine the compiled shaders into a `.metal-ar` archive
    let airFiles = sources.map { $0.deletingPathExtension().appendingPathExtension("air").path }
    var arguments = [
      "-sdk", "macosx", "metal-ar",
      "rcs", "default.metal-ar"]
    arguments.append(contentsOf: airFiles)
    let compilationProcess = Process.create(
      "/usr/bin/xcrun",
      arguments: arguments,
      directory: tempDirectory)
    
    let compilationResult = compilationProcess.runAndWait()
    if case let .failure(error) = compilationResult {
      return .failure(.failedToCreateMetalArchive(error))
    }
    
    // Convert the `metal-ar` archive into a `metallib` library
    let libraryCreationProcess = Process.create(
      "/usr/bin/xcrun",
      arguments: [
        "-sdk", "macosx", "metallib",
        "default.metal-ar",
        "-o", destination.appendingPathComponent("default.metallib").path
      ],
      directory: tempDirectory)
    
    let libraryCreationResult = libraryCreationProcess.runAndWait()
    if case let .failure(error) = libraryCreationResult {
      return .failure(.failedToCreateMetalLibrary(error))
    }
    
    return .success()
  }
}
