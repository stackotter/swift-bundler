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
    let config: Configuration
    do {
      let data = try Data(contentsOf: packageDir.appendingPathComponent("Bundle.json"))
      config = try JSONDecoder().decode(Configuration.self, from: data)
    } catch {
      log.error("Failed to load config from Bundle.json; \(error)")
      Foundation.exit(1)
    }

    let outputDir = self.outputDir ?? packageDir.appendingPathComponent(".build/bundler")
    let packageName = getPackageName(from: packageDir)

    // Build package
    let configuration = self.configuration ?? .debug
    log.info("Building package with \(configuration.rawValue) configuration")
    if Shell.getExitStatus("swift build -c \(configuration.rawValue)", packageDir, silent: false) != 0 {
      log.error("Build failed")
      Foundation.exit(1)
    }

    let buildDirSymlink = packageDir.appendingPathComponent(".build/\(configuration.rawValue)")
    let buildDir = buildDirSymlink.resolvingSymlinksInPath()

    // Create app folder structure
    log.info("Creating .app skeleton")
    let app = outputDir.appendingPathComponent("\(packageName).app")
    let appContents = app.appendingPathComponent("Contents")
    let appResources = appContents.appendingPathComponent("Resources")
    let appMacOS = appContents.appendingPathComponent("MacOS")

    do {
      if FileManager.default.itemExists(at: app, withType: .directory) {
        try FileManager.default.removeItem(at: app)
      }
      try FileManager.default.createDirectory(at: appResources)
      try FileManager.default.createDirectory(at: appMacOS)
    } catch {
      log.error("Failed to create .app folder structure; \(error)")
      Foundation.exit(1)
    }

    // Copy executable
    log.info("Copying executable")
    let executable = buildDir.appendingPathComponent(packageName)
    do {
      try FileManager.default.copyItem(at: executable, to: appMacOS.appendingPathComponent(packageName))
    } catch {
      log.error("Failed to copy built executable to \(appMacOS.appendingPathComponent(packageName).path); \(error)")
      Foundation.exit(1)
    }

    // Create app icon
    log.info("Creating app icon")
    let appIcns = packageDir.appendingPathComponent("AppIcon.icns")
    do {
      if FileManager.default.itemExists(at: appIcns, withType: .file) {
        log.info("Using precompiled AppIcon.icns")
        try FileManager.default.copyItem(at: appIcns, to: appResources.appendingPathComponent("AppIcon.icns"))
      } else {
        let iconFile = packageDir.appendingPathComponent("Icon1024x1024.png")
        if FileManager.default.itemExists(at: iconFile, withType: .file) {
          log.info("Compiling Icon1024x1024.png into AppIcon.icns")
          try createIcns(from: iconFile, outDir: appResources)
        } else {
          log.warning("No app icon found, skipping")
        }
      }
    } catch {
      log.error("Failed to create app icon; \(error)")
      Foundation.exit(1)
    }
    
    // Create PkgInfo
    log.info("Creating PkgInfo")
    var pkgInfo: [UInt8] = [0x41, 0x50, 0x50, 0x4c, 0x3f, 0x3f, 0x3f, 0x3f]
    let pkgInfoFile = appContents.appendingPathComponent("PkgInfo")
    do {
      try Data(bytes: &pkgInfo, count: pkgInfo.count).write(to: pkgInfoFile)
    } catch {
      log.error("Failed to create PkgInfo; \(error)")
      Foundation.exit(1)
    }

    // Create Info.plist
    log.info("Creating Info.plist")
    let infoPlistFile = appContents.appendingPathComponent("Info.plist")
    let infoPlist = createAppInfoPlist(
      packageName: packageName, 
      bundleIdentifier: config.bundleIdentifier, 
      versionString: config.versionString, 
      buildNumber: config.buildNumber, 
      category: config.category,
      minOSVersion: config.minOSVersion)
    do {
      try infoPlist.write(to: infoPlistFile, atomically: false, encoding: .utf8)
    } catch {
      log.error("Failed to create Info.plist at \(infoPlistFile.path); \(error)")
      Foundation.exit(1)
    }

    // Update Info.plist in xcodeproj if present
    let xcodeprojDir = packageDir.appendingPathComponent("\(packageName).xcodeproj")
    if FileManager.default.itemExists(at: xcodeprojDir, withType: .directory) {
      do {
        try infoPlist.write(to: xcodeprojDir.appendingPathComponent("\(packageName)_Info.plist"), atomically: false, encoding: .utf8)
      } catch {
        log.error("Failed to update Info.plist in xcodeproj; \(error)")
        Foundation.exit(1)
      }
    }

    // Copy bundles
    log.info("Copying bundles")
    let contents: [URL]
    do {
      contents = try FileManager.default.contentsOfDirectory(at: buildDir, includingPropertiesForKeys: nil, options: [])
    } catch {
      log.error("Failed to enumerate contents of build directory (\(buildDir)); \(error)")
      Foundation.exit(1)
    }

    let bundles = contents.filter { $0.pathExtension == "bundle" }
    for bundle in bundles {
      log.info("Copying \(bundle.lastPathComponent)")
      let contents: [URL]
      do {
        contents = try FileManager.default.contentsOfDirectory(at: bundle, includingPropertiesForKeys: nil, options: [])
      } catch {
        log.error("Failed to enumerate contents of '\(bundle.lastPathComponent)'; \(error)")
        Foundation.exit(1)
      }

      let outputBundle = appResources.appendingPathComponent(bundle.lastPathComponent)
      let bundleContents = outputBundle.appendingPathComponent("Contents")
      let bundleResources = bundleContents.appendingPathComponent("Resources")
      do {
        try FileManager.default.createDirectory(at: bundleResources, withIntermediateDirectories: true, attributes: nil)

        for file in contents {
          try FileManager.default.copyItem(at: file, to: bundleResources.appendingPathComponent(file.lastPathComponent))
        }
      } catch {
        log.error("Failed to create copy of '\(bundle.lastPathComponent)'; \(error)")
        Foundation.exit(1)
      }

      // Create Info.plist if missing
      let bundleName = bundle.deletingPathExtension().lastPathComponent
      let bundleIdentifier = bundleName.replacingOccurrences(of: "_", with: "-").appending("-resources")
      let infoPlistFile = bundleContents.appendingPathComponent("Info.plist")
      if !FileManager.default.itemExists(at: infoPlistFile, withType: .file) {
        log.info("Creating Info.plist for \(bundle.lastPathComponent)")
        let infoPlist = createBundleInfoPlist(bundleIdentifier: bundleIdentifier, bundleName: bundleName, minOSVersion: config.minOSVersion)
        do {
          try infoPlist.write(to: infoPlistFile, atomically: false, encoding: .utf8)
        } catch {
          log.error("Failed to create Info.plist for '\(bundle.lastPathComponent)'; \(error)")
          Foundation.exit(1)
        }
      }

      // Metal shader compilation
      let metalFiles = contents.filter { $0.pathExtension == "metal" }
      if metalFiles.isEmpty {
        continue
      }

      log.info("Compiling metal shaders in \(bundle.lastPathComponent)")

      for metalFile in metalFiles {
        let path = metalFile.deletingPathExtension().path
        if Shell.getExitStatus("xcrun -sdk macosx metal -c \(path).metal -o \(path).air", silent: false) != 0 {
          log.error("Failed to compile '\(metalFile.lastPathComponent)")
          Foundation.exit(1)
        }
      }
      
      let airFilePaths = metalFiles.map { $0.deletingPathExtension().appendingPathExtension("air").path }
      if Shell.getExitStatus("xcrun -sdk macosx metal-ar rcs \(outputBundle.path)/default.metal-ar \(airFilePaths.joined(separator: " "))", silent: false) != 0 {
        log.error("Failed to combine compiled metal shaders into a metal archive")
        Foundation.exit(1)
      }
      if Shell.getExitStatus("xcrun -sdk macosx metallib \(outputBundle.path)/default.metal-ar -o \(bundleResources.path)/default.metallib", silent: false) != 0 {
        log.error("Failed to convert metal archive to metal library")
        Foundation.exit(1)
      }
      Shell.runSilently("rm \(outputBundle.path)/default.metal-ar")
    }
  }
}