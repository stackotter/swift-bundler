import Foundation
import ArgumentParser

enum BuildConfiguration: String {
  case debug
  case release
}

struct Bundler: ParsableCommand {
  @Option(name: [.customLong("directory"), .customShort("d")], help: "The directory containing the package to be bundled", transform: URL.init(fileURLWithPath:))
  var packageDir: URL

  @Option(name: .shortAndLong, help: "The build configuration to use (debug|release)", transform: BuildConfiguration.init(rawValue:))
  var configuration: BuildConfiguration?

  mutating func run() throws {
    // Build package
    let configuration = self.configuration ?? .debug
    log.info("Building package with \(configuration.rawValue) configuration")
    shell("swift build -c \(configuration.rawValue)", packageDir, shouldPipe: false)

    // Clean up previous builds
    let buildDirSymlink = packageDir.appendingPathComponent(".build/\(configuration.rawValue)")
    let buildDir = buildDirSymlink.resolvingSymlinksInPath()
    let outputDir = packageDir.appendingPathComponent(".build/bundler")
    shell("rm -rf \(outputDir.path); mkdir \(outputDir.path)")

    // Create .app
    log.info("Creating .app skeleton")
    let packageName = String(shell(#"grep '\w*name: ".*",' Package.swift"#, packageDir).split(separator: "\n")[0].split(separator: "\"")[1])
    let app = outputDir.appendingPathComponent("\(packageName).app")
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
    log.info("Creating Info.plist")
    let bundleIdentifier = "dev.stackotter.delta-client"
    let versionString = "0.1.0"
    let buildNumber = 8
    let category = "public.app-category.games"
    let minOSVersion = "11.0"

    let infoPlist = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>\(packageName)</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleIconName</key>
	<string>AppIcon</string>
	<key>CFBundleIdentifier</key>
	<string>\(bundleIdentifier)</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>\(packageName)</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>\(versionString)</string>
	<key>CFBundleSupportedPlatforms</key>
	<array>
		<string>MacOSX</string>
	</array>
	<key>CFBundleVersion</key>
	<string>\(buildNumber)</string>
	<key>LSApplicationCategoryType</key>
	<string>\(category)</string>
	<key>LSMinimumSystemVersion</key>
	<string>\(minOSVersion)</string>
</dict>
</plist>
"""
    let infoPlistFile = appContents.appendingPathComponent("Info.plist")
    try! infoPlist.data(using: .utf8)!.write(to: infoPlistFile)

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
      let infoPlist = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIdentifier</key>
	<string>\(bundleIdentifier)</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>\(bundleName)</string>
	<key>CFBundlePackageType</key>
	<string>BNDL</string>
	<key>CFBundleSupportedPlatforms</key>
	<array>
		<string>MacOSX</string>
	</array>
	<key>LSMinimumSystemVersion</key>
	<string>\(minOSVersion)</string>
</dict>
</plist>
"""
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

  /// Creates an AppIcon.icns in the given directory from the given 1024x1024 input png.
  func createIcns(from icon1024: URL, outDir: URL) {
    let iconPath = icon1024.path
    let iconSet = outDir.appendingPathComponent("AppIcon.iconset").path
    shell("""
mkdir \(iconSet)
sips -z 16 16     \(iconPath) --out \(iconSet)/icon_16x16.png
sips -z 32 32     \(iconPath) --out \(iconSet)/icon_16x16@2x.png
sips -z 32 32     \(iconPath) --out \(iconSet)/icon_32x32.png
sips -z 64 64     \(iconPath) --out \(iconSet)/icon_32x32@2x.png
sips -z 128 128   \(iconPath) --out \(iconSet)/icon_128x128.png
sips -z 256 256   \(iconPath) --out \(iconSet)/icon_128x128@2x.png
sips -z 256 256   \(iconPath) --out \(iconSet)/icon_256x256.png
sips -z 512 512   \(iconPath) --out \(iconSet)/icon_256x256@2x.png
sips -z 512 512   \(iconPath) --out \(iconSet)/icon_512x512.png
cp \(iconPath) \(iconSet)/icon_512x512@2x.png
iconutil -c icns \(iconSet)
rm -R \(iconSet)
""")
  }
}

Bundler.main()

@discardableResult
func shell(_ command: String, _ dir: URL? = nil, shouldPipe: Bool = true) -> String {
  let task = Process()
  
  let pipe = Pipe()
  if shouldPipe {
    task.standardOutput = pipe
    task.standardError = pipe
  }

  if let dir = dir {
    task.arguments = ["-c", "cd \(dir.path); \(command)"]
  } else {
    task.arguments = ["-c", "\(command)"]
  }
  task.launchPath = "/bin/zsh"
  task.launch()
  
  if shouldPipe {
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)!
    return output
  } else {
    task.waitUntilExit()
    return ""
  }
}

// TODO: fix release build metallibs
// TODO: option to show build progress in a window
// TODO: codesigning
// TODO: graceful shutdown
// TODO: xcode support
// TODO: documentation