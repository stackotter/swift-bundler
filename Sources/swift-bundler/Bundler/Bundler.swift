import Foundation

enum BundlerError: LocalizedError {
  case failedToRunSwiftBuild(Error)
  case failedToCreateAppBundleDirectory(Error)
  case failedToCreatePkgInfo(Error)
  case failedToCreateInfoPlist(Error)
  case failedToCopyExecutable(Error)
}

struct Bundler {
  var context: Context
  var scriptRunner: ScriptRunner
  
  var appBundle: URL {
    context.outputDirectory.appendingPathComponent("\(context.appName).app")
  }
  
  var appExecutable: URL {
    appBundle.appendingPathComponent("Contents/MacOS/\(context.appName)")
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
  
  init(_ context: Context) {
    self.context = context
    scriptRunner = ScriptRunner(.init(
      packageDirectory: context.packageDirectory
    ))
  }
  
  func prebuild() throws {
    log.info("Running prebuild script")
    try scriptRunner.runPrebuildScriptIfPresent()
  }
  
  func build() throws {
    let buildConfiguration = context.buildConfiguration.rawValue
    log.info("Starting \(buildConfiguration) build")
    
    var arguments = ["build", "-c", buildConfiguration]
    if context.universal {
      arguments += ["--arch", "arm64", "--arch", "x86_64"]
    }
    
    let process = Process.create("/usr/bin/swift", arguments: arguments, directory: context.packageDirectory)
    do {
      try process.runAndWait()
    } catch {
      throw BundlerError.failedToRunSwiftBuild(error)
    }
  }
  
  func bundle() throws {
    // Create app bundle structure
    try createAppDirectoryStructure(at: appBundle)
    
    // Copy executable
    let executableArtifact = context.productsDirectory.appendingPathComponent(context.appConfiguration.target)
    try copyExecutable(at: executableArtifact, to: appExecutable)
    
    // Create `PkgInfo` and `Info.plist`
    try createMetadataFiles(
      at: appBundle.appendingPathComponent("Contents"),
      context: .init(
        appName: context.appName,
        configuration: context.appConfiguration
      ))
  }
  
  func postbuild() throws {
    log.info("Running postbuild script")
    try scriptRunner.runPostbuildScriptIfPresent()
  }
  
  func run() throws {
    log.info("Running '\(context.appName).app'")
    let process = Process.create(appExecutable.path)
    try process.run()
    process.waitUntilExit()
  }
  
  // MARK: Private methods
  
  /// Creates the following directory structure for the app:
  /// - `AppName.app`
  ///   - `Contents`
  ///     - `MacOS`
  ///
  /// - Parameter appBundleDirectory: The directory for the app (should be of the form `/path/to/AppName.app`).
  private func createAppDirectoryStructure(at appBundleDirectory: URL) throws {
    log.info("Creating '\(context.appName).app'")
    let fileManager = FileManager.default
    
    let appContents = appBundleDirectory.appendingPathComponent("Contents")
    let appMacOS = appContents.appendingPathComponent("MacOS")
    
    do {
      if fileManager.itemExists(at: appBundle, withType: .directory) {
        try fileManager.removeItem(at: appBundle)
      }
      try fileManager.createDirectory(at: appMacOS)
    } catch {
      throw BundlerError.failedToCreateAppBundleDirectory(error)
    }
  }
  
  /// Copies the built executable into the app bundle.
  /// - Parameters:
  ///   - source: The location of the built executable.
  ///   - destination: The target location of the built executable (the file not the directory).
  private func copyExecutable(at source: URL, to destination: URL) throws {
    log.info("Copying executable")
    do {
      try FileManager.default.copyItem(at: source, to: destination)
    } catch {
      throw BundlerError.failedToCopyExecutable(error)
    }
  }
  
  /// Creates an app's `PkgInfo` and `Info.plist` files.
  /// - Parameters:
  ///   - appContentsDirectory: The app's `Contents` directory.
  ///   - context: The context to create the `Info.plist` within.
  private func createMetadataFiles(at appContentsDirectory: URL, context: PlistCreator.Context) throws {
    log.info("Creating PkgInfo file")
    do {
      let pkgInfoFile = appContentsDirectory.appendingPathComponent("PkgInfo")
      var pkgInfoBytes: [UInt8] = [0x41, 0x50, 0x50, 0x4c, 0x3f, 0x3f, 0x3f, 0x3f]
      let pkgInfoData = Data(bytes: &pkgInfoBytes, count: pkgInfoBytes.count)
      try pkgInfoData.write(to: pkgInfoFile)
    } catch {
      throw BundlerError.failedToCreatePkgInfo(error)
    }
    
    log.info("Creating Info.plist")
    do {
      let infoPlistFile = appContentsDirectory.appendingPathComponent("Info.plist")
      let plistCreator = PlistCreator(context: context)
      try plistCreator.createAppInfoPlist(at: infoPlistFile)
    } catch {
      throw BundlerError.failedToCreateInfoPlist(error)
    }
  }
}
