import Foundation

enum PlistError: LocalizedError {
  case unknownPlistEntryType(String)
}

enum PlistUtil {
  static func createAppInfoPlist(appName: String, configuration: AppConfiguration) throws -> Data {
    var entries: [String: Any] = [
      "CFBundleExecutable": appName,
      "CFBundleIconFile": "AppIcon",
      "CFBundleIconName": "AppIcon",
      "CFBundleIdentifier": configuration.bundleIdentifier,
      "CFBundleInfoDictionaryVersion": "6.0",
      "CFBundleName": appName,
      "CFBundlePackageType": "APPL",
      "CFBundleShortVersionString": configuration.version,
      "CFBundleSupportedPlatforms": ["MacOSX"],
      "LSApplicationCategoryType": configuration.category,
      "LSMinimumSystemVersion": configuration.minMacOSVersion,
    ]
    
    for (key, value) in configuration.plistEntries {
      entries[key] = value.value
    }
    
    return try serialize(entries)
  }
  
  static func createBundleInfoPlist(
    bundleIdentifier: String,
    bundleName: String,
    minMacOSVersion: String
  ) throws -> Data {
    let entries: [String: Any] = [
      "CFBundleIdentifier": bundleIdentifier,
      "CFBundleInfoDictionaryVersion": "6.0",
      "CFBundleName": bundleName,
      "CFBundlePackageType": "BNDL",
      "CFBundleSupportedPlatforms": ["MacOSX"],
      "LSMinimumSystemVersion": minMacOSVersion,
    ]
    
    return try serialize(entries)
  }
  
  static func serialize(_ entries: [String: Any]) throws -> Data {
    return try PropertyListSerialization.data(fromPropertyList: entries, format: .xml, options: 0)
  }
}
