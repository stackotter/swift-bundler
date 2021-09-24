import Foundation

func getPackageName(from dir: URL) -> String {
  return String(shell(#"grep '\w*name: ".*",' Package.swift"#, dir).split(separator: "\n")[0].split(separator: "\"")[1])
}

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

func createAppInfoPlist(packageName: String, bundleIdentifier: String, versionString: String, buildNumber: Int, category: String, minOSVersion: String) -> String {
  return """
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
}

func createBundleInfoPlist(bundleIdentifier: String, bundleName: String, minOSVersion: String) -> String {
  return """
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
}