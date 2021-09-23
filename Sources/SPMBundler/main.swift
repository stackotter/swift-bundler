import Foundation
import ArgumentParser

@discardableResult
func shell(_ dir: URL, _ command: String) -> String {
  let task = Process()
  let pipe = Pipe()
  
  task.standardOutput = pipe
  task.standardError = pipe
  task.arguments = ["-c", "cd \(dir.path); \(command)"]
  task.launchPath = "/bin/zsh"
  task.launch()
  
  let data = pipe.fileHandleForReading.readDataToEndOfFile()
  let output = String(data: data, encoding: .utf8)!
  return output
}

struct Bundler: ParsableCommand {
  @Option(name: .shortAndLong, help: "The file URL we want.", transform: URL.init(fileURLWithPath:))
  var dir: URL

  mutating func run() throws {
    let packageDir = dir
    _ = shell(packageDir, "swift build")

    let buildDir = packageDir.appendingPathComponent(".build/x86_64-apple-macosx/debug") // TODO: use symlink to determine directory
    let outputDir = packageDir.appendingPathComponent(".build/bundler")
    shell(packageDir, "rm -rf \(outputDir.path); mkdir \(outputDir.path)")

    // Create .app
    let packageName = String(shell(packageDir, #"grep '\w*name: ".*",' Package.swift"#).split(separator: "\n")[0].split(separator: "\"")[1])
    let app = outputDir.appendingPathComponent("\(packageName).app")
    let appContents = app.appendingPathComponent("Contents")
    let appResources = appContents.appendingPathComponent("Resources")
    try! FileManager.default.createDirectory(at: appResources, withIntermediateDirectories: true, attributes: nil)
    let appMacOS = appContents.appendingPathComponent("MacOS")
    try! FileManager.default.createDirectory(at: appMacOS, withIntermediateDirectories: true, attributes: nil)

    // Copy executable
    let executable = buildDir.appendingPathComponent(packageName)
    try! FileManager.default.copyItem(at: executable, to: appMacOS.appendingPathComponent(packageName))
    
    // Write PkgInfo
    var pkgInfo: [UInt8] = [0x41, 0x50, 0x50, 0x4c, 0x3f, 0x3f, 0x3f, 0x3f]
    let pkgInfoFile = appContents.appendingPathComponent("PkgInfo")
    try! Data(bytes: &pkgInfo, count: pkgInfo.count).write(to: pkgInfoFile)

    // Write Info.plist
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

    for bundle in bundles {
      print("Copying '\(bundle.lastPathComponent)'")
      let contents = try! FileManager.default.contentsOfDirectory(at: bundle, includingPropertiesForKeys: nil, options: [])

      let outputBundle = appResources.appendingPathComponent(bundle.lastPathComponent)
      let bundleContents = outputBundle.appendingPathComponent("Contents")
      let bundleResources = bundleContents.appendingPathComponent("Resources")
      try! FileManager.default.createDirectory(at: bundleResources, withIntermediateDirectories: true, attributes: nil)

      for file in contents {
        try! FileManager.default.copyItem(at: file, to: bundleResources.appendingPathComponent(file.lastPathComponent))
      }

      // Write Info.plist
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

      print("Compiling metal shaders")

      for metalFile in metalFiles {
        let path = metalFile.deletingPathExtension().path
        shell(packageDir, "xcrun -sdk macosx metal -c \(path).metal -o \(path).air")
      }
      
      let airFilePaths = metalFiles.map { $0.deletingPathExtension().appendingPathExtension("air").path }
      shell(packageDir, "xcrun -sdk macosx metal-ar rcs \(outputBundle.path)/default.metal-ar \(airFilePaths.joined(separator: " "))")
      shell(packageDir, "xcrun -sdk macosx metallib \(outputBundle.path)/default.metal-ar -o \(bundleResources.path)/default.metallib")
      shell(packageDir, "rm \(outputBundle.path)/default.metal-ar")
    }
  }
}

Bundler.main()