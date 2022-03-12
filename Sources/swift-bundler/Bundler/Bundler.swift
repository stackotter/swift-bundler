import Foundation

enum BundlerError: LocalizedError {
  case failedToRunPrebuildScript(ScriptRunnerError)
  case failedToBuild(SwiftPackageManagerError)
  case failedToRunPostbuildScript(ScriptRunnerError)
  case failedToCreateAppBundleDirectoryStructure(Error)
  case failedToCreatePkgInfo(Error)
  case failedToCreateInfoPlist(PlistError)
  case failedToCopyExecutable(Error)
  case failedToCreateIcon(IconError)
  case failedToCopyICNS(Error)
  case failedToCopyResourceBundles(ResourceBundlerError)
  case failedToCopyDynamicLibraries(DynamicLibraryBundlerError)
  case failedToRunExecutable(ProcessError)
}

struct Bundler {
  var context: Context
  
  struct Context {
    var appConfiguration: AppConfiguration
    var buildConfiguration: SwiftPackageManager.BuildConfiguration
    var packageDirectory: URL
    var productsDirectory: URL
    var outputDirectory: URL
    var appName: String
    var universal: Bool
    
    var appBundle: URL {
      outputDirectory.appendingPathComponent("\(appName).app")
    }
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
    return SwiftPackageManager.build(
      product: context.appConfiguration.product,
      packageDirectory: context.packageDirectory,
      configuration: context.buildConfiguration,
      universal: context.universal
    ).mapError { error in
      .failedToBuild(error)
    }
  }
  
  /// Bundles the built executable into a macOS app.
  /// - Returns: If a failure occurs, it is returned.
  func bundle() -> Result<Void, BundlerError> {
    let executableArtifact = context.productsDirectory.appendingPathComponent(context.appConfiguration.product)
    
    let appContents = context.appBundle.appendingPathComponent("Contents")
    let appExecutable = appContents.appendingPathComponent("MacOS/\(context.appName)")
    let appResources = appContents.appendingPathComponent("Resources")
    let appDynamicLibrariesDirectory = appContents.appendingPathComponent("Libraries")
    
    let copyResourcesBundles: () -> Result<Void, BundlerError> = {
      ResourceBundler.copyResourceBundles(
        from: context.productsDirectory,
        to: appResources,
        isXcodeBuild: false,
        minMacOSVersion: context.appConfiguration.minMacOSVersion
      ).mapError { error in
        .failedToCopyResourceBundles(error)
      }
    }
    
    let copyDynamicLibraries: () -> Result<Void, BundlerError> = {
      DynamicLibraryBundler.copyDynamicLibraries(
        from: context.productsDirectory,
        to: appDynamicLibrariesDirectory,
        appExecutable: appExecutable,
        isXcodeBuild: false
      ).mapError { error in
          .failedToCopyDynamicLibraries(error)
      }
    }
    
    let bundleApp = flatten(
      { Self.createAppDirectoryStructure(at: context.outputDirectory, appName: context.appName) },
      { Self.copyExecutable(at: executableArtifact, to: appExecutable) },
      { Self.createMetadataFiles(at: appContents, appName: context.appName, appConfiguration: context.appConfiguration) },
      { Self.createAppIcon(from: context.packageDirectory, outputDirectory: appResources) },
      { copyResourcesBundles() },
      { copyDynamicLibraries() })
    
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
  
  /// Runs the app (without building or bundling first).
  /// - Returns: Returns a failure if the app fails to run.
  func run() -> Result<Void, BundlerError> {
    log.info("Running '\(context.appName).app'")
    let appExecutable = context.appBundle.appendingPathComponent("Contents/MacOS/\(context.appName)")
    let process = Process.create(appExecutable.path)
    return process.runAndWait()
      .mapError { error in
        .failedToRunExecutable(error)
      }
  }
  
  // MARK: Private methods
  
  /// Creates the directory structure for an app.
  ///
  /// Creates the following structure:
  ///
  /// - `AppName.app`
  ///   - `Contents`
  ///     - `MacOS`
  ///     - `Resources`
  ///     - `Libraries`
  ///
  /// - Parameters:
  ///   - outputDirectory: The directory to output the app to.
  ///   - appName: The name of the app.
  private static func createAppDirectoryStructure(at outputDirectory: URL, appName: String) -> Result<Void, BundlerError> {
    log.info("Creating '\(appName).app'")
    let fileManager = FileManager.default
    
    let appBundleDirectory = outputDirectory.appendingPathComponent("\(appName).app")
    let appContents = appBundleDirectory.appendingPathComponent("Contents")
    let appResources = appContents.appendingPathComponent("Resources")
    let appMacOS = appContents.appendingPathComponent("MacOS")
    let appDynamicLibrariesDirectory = appContents.appendingPathComponent("Libraries")
    
    do {
      if fileManager.itemExists(at: appBundleDirectory, withType: .directory) {
        try fileManager.removeItem(at: appBundleDirectory)
      }
      try fileManager.createDirectory(at: appResources)
      try fileManager.createDirectory(at: appMacOS)
      try fileManager.createDirectory(at: appDynamicLibrariesDirectory)
      return .success()
    } catch {
      return .failure(.failedToCreateAppBundleDirectoryStructure(error))
    }
  }
  
  /// Copies the built executable into the app bundle.
  /// - Parameters:
  ///   - source: The location of the built executable.
  ///   - destination: The target location of the built executable (the file not the directory).
  private static func copyExecutable(at source: URL, to destination: URL) -> Result<Void, BundlerError> {
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
  ///   - outputDirectory: Should be the app's `Contents` directory.
  private static func createMetadataFiles(at outputDirectory: URL, appName: String, appConfiguration: AppConfiguration) -> Result<Void, BundlerError> {
    log.info("Creating 'PkgInfo'")
    do {
      let pkgInfoFile = outputDirectory.appendingPathComponent("PkgInfo")
      var pkgInfoBytes: [UInt8] = [0x41, 0x50, 0x50, 0x4c, 0x3f, 0x3f, 0x3f, 0x3f]
      let pkgInfoData = Data(bytes: &pkgInfoBytes, count: pkgInfoBytes.count)
      try pkgInfoData.write(to: pkgInfoFile)
    } catch {
      return .failure(.failedToCreatePkgInfo(error))
    }
    
    log.info("Creating 'Info.plist'")
    let infoPlistFile = outputDirectory.appendingPathComponent("Info.plist")
    return PlistCreator.createAppInfoPlist(at: infoPlistFile, appName: appName, appConfiguration: appConfiguration)
      .mapError { error in
        .failedToCreateInfoPlist(error)
      }
  }
  
  /// Copies `AppIcon.icns` into the app bundle if present. Alternatively, it creates the app's `AppIcon.icns` from a png if an `Icon1024x1024.png` is present.
  ///
  /// `AppIcon.icns` takes precendence over `Icon1024x1024.png`.
  /// - Parameter outputDirectory: Should be the app's `Resources` directory.
  /// - Returns: If `Icon1024x1024.png` exists and there is an error while converting it to `icns`, a failure is returned.
  private static func createAppIcon(from packageDirectory: URL, outputDirectory: URL) -> Result<Void, BundlerError> {
    // Copy `AppIcon.icns` if present
    let icnsFile = packageDirectory.appendingPathComponent("AppIcon.icns")
    if FileManager.default.itemExists(at: icnsFile, withType: .file) {
      log.info("Copying 'AppIcon.icns'")
      do {
        try FileManager.default.copyItem(at: icnsFile, to: outputDirectory.appendingPathComponent("AppIcon.icns"))
        return .success()
      } catch {
        return .failure(.failedToCopyICNS(error))
      }
    }
    
    // Create `AppIcon.icns` from `Icon1024x1024.png` if present
    let iconFile = packageDirectory.appendingPathComponent("Icon1024x1024.png")
    if FileManager.default.itemExists(at: iconFile, withType: .file) {
      log.info("Creating 'AppIcon.icns' from 'Icon1024x1024.png'")
      return IconSetCreator.createIcns(from: iconFile, outputDirectory: outputDirectory)
        .mapError { error in
          .failedToCreateIcon(error)
        }
    }
    
    return .success()
  }
}
