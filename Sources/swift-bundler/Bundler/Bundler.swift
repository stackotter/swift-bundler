import Foundation

enum BundlerError: LocalizedError {
  case failedToRunSwiftBuild(Error)
  case failedToCreateAppBundleDirectory(Error)
  case failedToCreatePkgInfo(Error)
  case failedToCreateInfoPlist(Error)
}

struct Bundler {
  var context: Context
  var scriptRunner: ScriptRunner
  
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
    log.info("Creating '\(context.appName).app'")
    let fileManager = FileManager.default
    let executable = context.productsDirectory.appendingPathComponent(context.appConfiguration.target)
    
    // Create an empty app bundle
    let app = context.outputDirectory.appendingPathComponent("\(context.appName).app")
    let appContents = app.appendingPathComponent("Contents")
    let appMacOS = appContents.appendingPathComponent("MacOS")
    
    do {
      if fileManager.itemExists(at: app, withType: .directory) {
        try fileManager.removeItem(at: app)
      }
      try fileManager.createDirectory(at: appMacOS)
    } catch {
      throw BundlerError.failedToCreateAppBundleDirectory(error)
    }
    
    log.info("Copying executable")
    do {
      let process = Process.create(
        "/usr/bin/install_name_tool",
        arguments: ["-add_rpath", "@executable_path", executable.path])
      try process.runAndWait()
      try fileManager.copyItem(at: executable, to: appMacOS.appendingPathComponent("\(context.appName)"))
    }
    
    log.info("Creating PkgInfo file")
    do {
      let pkgInfoFile = appContents.appendingPathComponent("PkgInfo")
      var pkgInfoBytes: [UInt8] = [0x41, 0x50, 0x50, 0x4c, 0x3f, 0x3f, 0x3f, 0x3f]
      let pkgInfoData = Data(bytes: &pkgInfoBytes, count: pkgInfoBytes.count)
      try pkgInfoData.write(to: pkgInfoFile)
    } catch {
      throw BundlerError.failedToCreatePkgInfo(error)
    }
    
    log.info("Creating Info.plist")
    do {
      let infoPlistFile = appContents.appendingPathComponent("Info.plist")
      let infoPlistContents = try PlistUtil.createAppInfoPlist(
        appName: context.appName,
        configuration: context.appConfiguration)
      try infoPlistContents.write(to: infoPlistFile)
    } catch {
      throw BundlerError.failedToCreateInfoPlist(error)
    }
  }
  
  func postbuild() throws {
    log.info("Running postbuild script")
    try scriptRunner.runPostbuildScriptIfPresent()
  }
}
