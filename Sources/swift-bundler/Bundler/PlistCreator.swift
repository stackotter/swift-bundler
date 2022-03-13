import Foundation
import Parsing

enum PlistError: LocalizedError {
  case unknownPlistEntryType(String)
  case failedToWriteAppInfoPlist(URL, Error)
  case serializationFailed(Error)
}

/// A utility for creating the contents of plist files.
enum PlistCreator {
  /// Creates an app's `Info.plist` file.
  /// - Parameters:
  ///   - file: The URL of the file to create.
  ///   - appName: The name of the app.
  ///   - bundleIdentifier: The app's bundle identifier (e.g. `com.example.HelloWorldApp`).
  ///   - version: The app's version string.
  ///   - category: The app's category.
  ///   - minMacOSVersion: The app's minimum macOS version.
  ///   - extraPlistEntries: Extra entries to insert into `Info.plist`.
  static func createAppInfoPlist(
    at file: URL,
    appName: String,
    bundleIdentifier: String,
    version: String,
    category: String,
    minMacOSVersion: String,
    extraPlistEntries: [String: String]
  ) -> Result<Void, PlistError> {
    createAppInfoPlistContents(
      appName: appName,
      bundleIdentifier: bundleIdentifier,
      version: version,
      category: category,
      minMacOSVersion: minMacOSVersion,
      extraPlistEntries: extraPlistEntries
    ).flatMap { contents in
      do {
        try contents.write(to: file)
        return .success()
      } catch {
        return .failure(.failedToWriteAppInfoPlist(file, error))
      }
    }
  }
  
  /// Creates the `Info.plist` file for a resource bundle.
  /// - Parameters:
  ///   - file: The URL of the file to create.
  ///   - bundleName: The bundle's name.
  static func createResourceBundleInfoPlist(at file: URL, bundleName: String, minMacOSVersion: String) -> Result<Void, PlistError> {
    createResourceBundleInfoPlistContents(bundleName: bundleName, minMacOSVersion: minMacOSVersion)
      .flatMap { contents in
        do {
          try contents.write(to: file)
          return .success()
        } catch {
          return .failure(.failedToWriteAppInfoPlist(file, error))
        }
      }
  }
  
  /// Creates the contents of an app's `Info.plist` file.
  /// - Parameters:
  ///   - appName: The app's name.
  ///   - bundleIdentifier: The app's bundle identifier (e.g. `com.example.HelloWorldApp`).
  ///   - version: The app's version string.
  ///   - category: The app's category.
  ///   - minMacOSVersion: The app's minimum macOS version.
  ///   - extraPlistEntries: Extra entries to insert into `Info.plist`.
  /// - Returns: The generated contents for the `Info.plist` file.
  static func createAppInfoPlistContents(
    appName: String,
    bundleIdentifier: String,
    version: String,
    category: String,
    minMacOSVersion: String,
    extraPlistEntries: [String: String]
  ) -> Result<Data, PlistError> {
    var entries: [String: Any] = [
      "CFBundleExecutable": appName,
      "CFBundleIconFile": "AppIcon",
      "CFBundleIconName": "AppIcon",
      "CFBundleIdentifier": bundleIdentifier,
      "CFBundleInfoDictionaryVersion": "6.0",
      "CFBundleName": appName,
      "CFBundlePackageType": "APPL",
      "CFBundleShortVersionString": version,
      "CFBundleSupportedPlatforms": ["MacOSX"],
      "LSApplicationCategoryType": category,
      "LSMinimumSystemVersion": minMacOSVersion,
    ]
    
    for (key, value) in extraPlistEntries {
      entries[key] = value
    }
    
    return Self.serialize(entries)
  }
  
  /// Creates the contents of a resource bundle's `Info.plist` file.
  /// - Parameters:
  ///   - bundleName: The bundle's name.
  /// - Returns: The generated contents for the `Info.plist` file.
  static func createResourceBundleInfoPlistContents(bundleName: String, minMacOSVersion: String) -> Result<Data, PlistError> {
    let bundleIdentifier = bundleName.replacingOccurrences(of: "_", with: "-") + "-resources"
    let entries: [String: Any] = [
      "CFBundleIdentifier": bundleIdentifier,
      "CFBundleInfoDictionaryVersion": "6.0",
      "CFBundleName": bundleName,
      "CFBundlePackageType": "BNDL",
      "CFBundleSupportedPlatforms": ["MacOSX"],
      "LSMinimumSystemVersion": minMacOSVersion,
    ]
    
    return Self.serialize(entries)
  }
  
  /// Serializes a plist dictionary into an `xml` format.
  /// - Parameter entries: The dictionary of entries to serialize.
  /// - Returns: The serialized plist file.
  static func serialize(_ entries: [String: Any]) -> Result<Data, PlistError> {
    do {
      let data = try PropertyListSerialization.data(fromPropertyList: entries, format: .xml, options: 0)
      return .success(data)
    } catch {
      return .failure(.serializationFailed(error))
    }
  }
}
