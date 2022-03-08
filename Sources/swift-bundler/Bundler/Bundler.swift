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
  case failedToCopyResourceBundles(ResourceBundlerError)
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
    let appDynamicLibrariesDirectory = appContents.appendingPathComponent("")
    
    let bundleApp = flatten(
      { createAppDirectoryStructure(at: appBundle) },
      { copyExecutable(at: executableArtifact, to: appExecutable) },
      { createMetadataFiles(at: appContents) },
      { createAppIcon(appResources) },
      {
        ResourceBundler.copyResourceBundles(
          from: context.productsDirectory,
          to: appResources,
          isXcodeBuild: false,
          minMacOSVersion: context.appConfiguration.minMacOSVersion
        ).mapError { error in
          .failedToCopyResourceBundles(error)
        }
      },
      { copyDynamicLibraries(from: context.productsDirectory, to: ) })
    
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
    return PlistCreator.createAppInfoPlist(at: infoPlistFile, appName: context.appName, appConfiguration: context.appConfiguration)
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
}
