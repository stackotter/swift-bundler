import ArgumentParser
import Foundation

struct Build: ParsableCommand {
  @Option(name: [.customLong("directory"), .customShort("d")], help: "The directory containing the package to be bundled", transform: URL.init(fileURLWithPath:))
  var packageDir: URL

  @Option(name: .shortAndLong, help: "The build configuration to use (debug|release)", transform: BuildConfiguration.init(rawValue:))
  var configuration: BuildConfiguration?

  @Option(name: .shortAndLong, help: "The directory to output the bundled .app to", transform: URL.init(fileURLWithPath:))
  var outputDir: URL?

  mutating func run() throws {
    log.info("Loading configuration")
    let data = try! Data(contentsOf: packageDir.appendingPathComponent("Bundle.json"))
    let config = try! JSONDecoder().decode(Configuration.self, from: data)

    let outputDir = self.outputDir ?? packageDir.appendingPathComponent(".build/bundler")
    let packageName = getPackageName(from: packageDir)

    // Build package
    let configuration = self.configuration ?? .debug
    log.info("Building package with \(configuration.rawValue) configuration")
    shell("swift build -c \(configuration.rawValue)", packageDir, shouldPipe: false)

    let buildDirSymlink = packageDir.appendingPathComponent(".build/\(configuration.rawValue)")
    let buildDir = buildDirSymlink.resolvingSymlinksInPath()

    // Create .app
    log.info("Creating .app skeleton")
    let app = outputDir.appendingPathComponent("\(packageName).app")
    shell("rm -rf \(app.path); mkdir \(app.path)")
    let appContents = app.appendingPathComponent("Contents")
    let appResources = appContents.appendingPathComponent("Resources")
    try! FileManager.default.createDirectory(at: appResources)
    let appMacOS = appContents.appendingPathComponent("MacOS")
    try! FileManager.default.createDirectory(at: appMacOS)

    // Copy executable
    log.info("Copying executable")
    let executable = buildDir.appendingPathComponent(packageName)
    try! FileManager.default.copyItem(at: executable, to: appMacOS.appendingPathComponent(packageName))

    // Create app icon
    let appIcns = packageDir.appendingPathComponent("AppIcon.icns")
    if FileManager.default.itemExists(at: appIcns, withType: .file) {
      log.info("Using precompiled AppIcon.icns")
      try! FileManager.default.copyItem(at: appIcns, to: appResources.appendingPathComponent("AppIcon.icns"))
    } else {
      let iconFile = packageDir.appendingPathComponent("Icon1024x1024.png")
      if FileManager.default.itemExists(at: iconFile, withType: .file) {
        log.info("Compiling Icon1024x1024.png into AppIcon.icns")
        createIcns(from: iconFile, outDir: appResources)
      } else {
        log.warning("No app icon found, skipping")
      }
    }
    
    // Write PkgInfo
    log.info("Creating PkgInfo")
    var pkgInfo: [UInt8] = [0x41, 0x50, 0x50, 0x4c, 0x3f, 0x3f, 0x3f, 0x3f]
    let pkgInfoFile = appContents.appendingPathComponent("PkgInfo")
    try! Data(bytes: &pkgInfo, count: pkgInfo.count).write(to: pkgInfoFile)

    // Write Info.plist
    log.info("Copying Info.plist")
    let infoPlistFile = appContents.appendingPathComponent("Info.plist")
    let xcodeprojDir = packageDir.appendingPathComponent("\(packageName).xcodeproj")
    try! FileManager.default.copyItem(at: xcodeprojDir.appendingPathComponent("\(packageName)_Info.plist"), to: infoPlistFile)

    // Copy bundles
    let contents = try! FileManager.default.contentsOfDirectory(at: buildDir, includingPropertiesForKeys: nil, options: [])
    let bundles = contents.filter { $0.pathExtension == "bundle" }

    if !bundles.isEmpty {
      log.info("Copying bundles")
    }

    for bundle in bundles {
      log.info("Copying \(bundle.lastPathComponent)")
      let contents = try! FileManager.default.contentsOfDirectory(at: bundle, includingPropertiesForKeys: nil, options: [])

      let outputBundle = appResources.appendingPathComponent(bundle.lastPathComponent)
      let bundleContents = outputBundle.appendingPathComponent("Contents")
      let bundleResources = bundleContents.appendingPathComponent("Resources")
      try! FileManager.default.createDirectory(at: bundleResources, withIntermediateDirectories: true, attributes: nil)

      for file in contents {
        try! FileManager.default.copyItem(at: file, to: bundleResources.appendingPathComponent(file.lastPathComponent))
      }

      // Write Info.plist
      log.info("Creating Info.plist for \(bundle.lastPathComponent)")
      let bundleName = bundle.deletingPathExtension().lastPathComponent
      let bundleIdentifier = bundleName.replacingOccurrences(of: "_", with: "-").appending("-resources")
      let infoPlistFile = bundleContents.appendingPathComponent("Info.plist")
      let infoPlist = createBundleInfoPlist(bundleIdentifier: bundleIdentifier, bundleName: bundleName, minOSVersion: config.minOSVersion)
      try! infoPlist.data(using: .utf8)!.write(to: infoPlistFile)

      // Metal shader compilation
      let metalFiles = contents.filter { $0.pathExtension == "metal" }
      if metalFiles.isEmpty {
        continue
      }

      log.info("Compiling metal shaders in \(bundle.lastPathComponent)")

      for metalFile in metalFiles {
        let path = metalFile.deletingPathExtension().path
        shell("xcrun -sdk macosx metal -c \(path).metal -o \(path).air", packageDir, shouldPipe: false)
      }
      
      let airFilePaths = metalFiles.map { $0.deletingPathExtension().appendingPathExtension("air").path }
      shell("xcrun -sdk macosx metal-ar rcs \(outputBundle.path)/default.metal-ar \(airFilePaths.joined(separator: " "))", packageDir, shouldPipe: false)
      shell("xcrun -sdk macosx metallib \(outputBundle.path)/default.metal-ar -o \(bundleResources.path)/default.metallib", packageDir, shouldPipe: false)
      shell("rm \(outputBundle.path)/default.metal-ar", packageDir)
    }
  }
}