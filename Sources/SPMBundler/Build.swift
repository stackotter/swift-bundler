import ArgumentParser
import Foundation

struct Build: ParsableCommand {
  @Option(name: [.customLong("directory"), .customShort("d")], help: "The directory containing the package to be bundled", transform: URL.init(fileURLWithPath:))
  var packageDir: URL

  @Option(name: .shortAndLong, help: "The build configuration to use (debug|release)", transform: { BuildConfiguration.init(rawValue: $0.lowercased()) })
  var configuration: BuildConfiguration?

  @Option(name: .shortAndLong, help: "The directory to output the bundled .app to", transform: URL.init(fileURLWithPath:))
  var outputDir: URL?

  @Flag(name: [.customShort("p"), .customLong("progress")], help: "Display progress in a window")
  var displayProgress = false

  func run() throws {
    if displayProgress {
      runProgressJob({ setMessage, setProgress in 
        job(setMessage, setProgress)
      },
      title: "Build",
      maxProgress: 1)
    } else {
      job({ _ in }, { _ in })
    }
  }

  func job(_ setMessage: @escaping (_ message: String) -> Void, _ setProgress: @escaping (_ progress: Double) -> Void) {
    func updateProgress(_ message: String, _ progress: Double, shouldLog: Bool = true) {
      if shouldLog {
        log.info(message)
      }
      setMessage(message)
      setProgress(progress)
    }

    updateProgress("Loading configuration", 0.05)
    let config: Configuration
    do {
      let data = try Data(contentsOf: packageDir.appendingPathComponent("Bundle.json"))
      config = try JSONDecoder().decode(Configuration.self, from: data)
    } catch {
      terminate("Failed to load config from Bundle.json; \(error)")
    }

    let outputDir = self.outputDir ?? packageDir.appendingPathComponent(".build/bundler")
    let packageName = getPackageName(from: packageDir)

    // Build package
    let configuration = self.configuration ?? .debug
    updateProgress("Starting build with \(configuration.rawValue) configuration...", 0.1)
    let exitStatus = Shell.getExitStatus("swift build -c \(configuration.rawValue)", packageDir, silent: false, lineHandler: { line in
      if line.starts(with: "[") {
        let parts = line.split(separator: "]")
        // let message = String(parts[1].dropFirst())
        let progressParts = parts[0].dropFirst().split(separator: "/")
        let progress = Double(progressParts[0])!
        let total = Double(progressParts[1])!
        let percentage = progress / total
        updateProgress(line, 0.8 * percentage + 0.1, shouldLog: false)
      }
    })
    if exitStatus != 0 {
      terminate("Build failed")
    }

    let buildDirSymlink = packageDir.appendingPathComponent(".build/\(configuration.rawValue)")
    let buildDir = buildDirSymlink.resolvingSymlinksInPath()

    // Create app folder structure
    updateProgress("Creating .app skeleton", 0.9)
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
      terminate("Failed to create .app folder structure; \(error)")
    }

    // Copy executable
    updateProgress("Copying executable", 0.91)
    let executable = buildDir.appendingPathComponent(packageName)
    do {
      try FileManager.default.copyItem(at: executable, to: appMacOS.appendingPathComponent(packageName))
    } catch {
      terminate("Failed to copy built executable to \(appMacOS.appendingPathComponent(packageName).path); \(error)")
    }

    // Create app icon
    updateProgress("Creating app icon", 0.92)
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
          log.warning("No app icon found. Create an Icon1024x1024.png or AppIcon.icns in the root directory to add an app icon.")
        }
      }
    } catch {
      terminate("Failed to create app icon; \(error)")
    }
    
    // Create PkgInfo
    updateProgress("Creating PkgInfo", 0.94)
    var pkgInfo: [UInt8] = [0x41, 0x50, 0x50, 0x4c, 0x3f, 0x3f, 0x3f, 0x3f]
    let pkgInfoFile = appContents.appendingPathComponent("PkgInfo")
    do {
      try Data(bytes: &pkgInfo, count: pkgInfo.count).write(to: pkgInfoFile)
    } catch {
      terminate("Failed to create PkgInfo; \(error)")
    }

    // Create Info.plist
    updateProgress("Creating Info.plist", 0.94)
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
      terminate("Failed to create Info.plist at \(infoPlistFile.path); \(error)")
    }

    // Update Info.plist in xcodeproj if present
    let xcodeprojDir = packageDir.appendingPathComponent("\(packageName).xcodeproj")
    if FileManager.default.itemExists(at: xcodeprojDir, withType: .directory) {
      do {
        try infoPlist.write(to: xcodeprojDir.appendingPathComponent("\(packageName)_Info.plist"), atomically: false, encoding: .utf8)
      } catch {
        terminate("Failed to update Info.plist in xcodeproj; \(error)")
      }
    }

    // Copy bundles
    updateProgress("Copying bundles", 0.94)
    let contents: [URL]
    do {
      contents = try FileManager.default.contentsOfDirectory(at: buildDir, includingPropertiesForKeys: nil, options: [])
    } catch {
      terminate("Failed to enumerate contents of build directory (\(buildDir)); \(error)")
    }

    let bundles = contents.filter { $0.pathExtension == "bundle" }
    for bundle in bundles {
      updateProgress("Copying \(bundle.lastPathComponent)", 0.94)
      let contents: [URL]
      do {
        contents = try FileManager.default.contentsOfDirectory(at: bundle, includingPropertiesForKeys: nil, options: [])
      } catch {
        terminate("Failed to enumerate contents of '\(bundle.lastPathComponent)'; \(error)")
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
        terminate("Failed to create copy of '\(bundle.lastPathComponent)'; \(error)")
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
          terminate("Failed to create Info.plist for '\(bundle.lastPathComponent)'; \(error)")
        }
      }

      // Metal shader compilation
      let metalFiles = contents.filter { $0.pathExtension == "metal" }
      if metalFiles.isEmpty {
        continue
      }

      updateProgress("Compiling metal shaders in \(bundle.lastPathComponent)", 0.95)

      for metalFile in metalFiles {
        let path = metalFile.deletingPathExtension().path
        if Shell.getExitStatus("xcrun -sdk macosx metal -c \(path).metal -o \(path).air", silent: false) != 0 {
          terminate("Failed to compile '\(metalFile.lastPathComponent)")
        }
      }
      
      let airFilePaths = metalFiles.map { $0.deletingPathExtension().appendingPathExtension("air").path }
      if Shell.getExitStatus("xcrun -sdk macosx metal-ar rcs \(outputBundle.path)/default.metal-ar \(airFilePaths.joined(separator: " "))", silent: false) != 0 {
        terminate("Failed to combine compiled metal shaders into a metal archive")
      }
      if Shell.getExitStatus("xcrun -sdk macosx metallib \(outputBundle.path)/default.metal-ar -o \(bundleResources.path)/default.metallib", silent: false) != 0 {
        terminate("Failed to convert metal archive to metal library")
      }
      Shell.runSilently("rm \(outputBundle.path)/default.metal-ar")
    }
    updateProgress("Done", 1)
  }
}