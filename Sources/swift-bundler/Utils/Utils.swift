import Foundation

enum BundlerError: LocalizedError {
	case icnsCreationFailed(exitStatus: Int)
}

/// Creates an AppIcon.icns in the given directory from the given 1024x1024 input png.
func createIcns(from icon1024: URL, outDir: URL) throws {
  let iconPath = icon1024.escapedPath
  let iconSetPath = outDir.appendingPathComponent("AppIcon.iconset").escapedPath
	let exitStatus = Shell.getExitStatus("""
mkdir \(iconSetPath)
sips -z 16 16     \(iconPath) --out \(iconSetPath)/icon_16x16.png
sips -z 32 32     \(iconPath) --out \(iconSetPath)/icon_16x16@2x.png
sips -z 32 32     \(iconPath) --out \(iconSetPath)/icon_32x32.png
sips -z 64 64     \(iconPath) --out \(iconSetPath)/icon_32x32@2x.png
sips -z 128 128   \(iconPath) --out \(iconSetPath)/icon_128x128.png
sips -z 256 256   \(iconPath) --out \(iconSetPath)/icon_128x128@2x.png
sips -z 256 256   \(iconPath) --out \(iconSetPath)/icon_256x256.png
sips -z 512 512   \(iconPath) --out \(iconSetPath)/icon_256x256@2x.png
sips -z 512 512   \(iconPath) --out \(iconSetPath)/icon_512x512.png
cp \(iconPath) \(iconSetPath)/icon_512x512@2x.png
iconutil -c icns \(iconSetPath)
rm -R \(iconSetPath)
""", silent: true)
  if exitStatus != 0 {
		throw BundlerError.icnsCreationFailed(exitStatus: exitStatus)
	}
}

func createAppInfoPlist(appName: String, bundleIdentifier: String, versionString: String, buildNumber: Int, category: String, minOSVersion: String, extraEntries: [String: Any]) throws -> Data {
  var entries: [String: Any] = [
    "CFBundleExecutable": appName,
    "CFBundleIconFile": "AppIcon",
    "CFBundleIconName": "AppIcon",
    "CFBundleIdentifier": bundleIdentifier,
    "CFBundleInfoDictionaryVersion": "6.0",
    "CFBundleName": appName,
    "CFBundlePackageType": "APPL",
    "CFBundleShortVersionString": versionString,
    "CFBundleSupportedPlatforms": ["MacOSX"],
    "CFBundleVersion": "\(buildNumber)",
    "LSApplicationCategoryType": category,
    "LSMinimumSystemVersion": minOSVersion,
  ]
  
  for (key, value) in extraEntries {
    entries[key] = value
  }
  
  return try PropertyListSerialization.data(fromPropertyList: entries, format: .xml, options: 0)
}

func createBundleInfoPlist(bundleIdentifier: String, bundleName: String, minOSVersion: String) throws -> Data {
  let entries: [String: Any] = [
    "CFBundleIdentifier": bundleIdentifier,
    "CFBundleInfoDictionaryVersion": "6.0",
    "CFBundleName": bundleName,
    "CFBundlePackageType": "BNDL",
    "CFBundleSupportedPlatforms": ["MacOSX"],
    "LSMinimumSystemVersion": minOSVersion,
  ]
  
  return try PropertyListSerialization.data(fromPropertyList: entries, format: .xml, options: 0)
}

func terminate(_ message: String) -> Never {
	log.error(message)
	Shell.terminateTasks()
	Foundation.exit(1)
}
