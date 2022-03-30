import Foundation
import Parsing

/// A utility for creating the contents of plist files.
enum PlistCreator {
  /// Creates an app's `Info.plist` file.
  /// - Parameters:
  ///   - file: The URL of the file to create.
  ///   - appName: The name of the app.
  ///   - bundleIdentifier: The app's bundle identifier (e.g. `com.example.HelloWorldApp`).
  ///   - version: The app's version string.
  ///   - category: The app's category.
  ///   - minimumMacOSVersion: The minimum macOS version that the app should run on.
  ///   - extraPlistEntries: Extra entries to insert into `Info.plist`.
  /// - Returns: If an error occurs, a failure is returned.
  static func createAppInfoPlist(
    at file: URL,
    appName: String,
    bundleIdentifier: String,
    version: String,
    category: String?,
    minimumMacOSVersion: String,
    extraPlistEntries: [String: String]
  ) -> Result<Void, PlistCreatorError> {
    createAppInfoPlistContents(
      appName: appName,
      bundleIdentifier: bundleIdentifier,
      version: version,
      category: category,
      minimumMacOSVersion: minimumMacOSVersion,
      extraPlistEntries: extraPlistEntries
    ).flatMap { contents in
      do {
        try contents.write(to: file)
        return .success()
      } catch {
        return .failure(.failedToWriteAppInfoPlist(file: file, error))
      }
    }
  }
  
  /// Creates the `Info.plist` file for a resource bundle.
  /// - Parameters:
  ///   - file: The URL of the file to create.
  ///   - bundleName: The bundle's name.
  ///   - minimumMacOSVersion: The minimum macOS version that the resource bundle should work on.
  /// - Returns: If an error occurs, a failure is returned.
  static func createResourceBundleInfoPlist(at file: URL, bundleName: String, minimumMacOSVersion: String) -> Result<Void, PlistCreatorError> {
    createResourceBundleInfoPlistContents(bundleName: bundleName, minimumMacOSVersion: minimumMacOSVersion)
      .flatMap { contents in
        do {
          try contents.write(to: file)
          return .success()
        } catch {
          return .failure(.failedToWriteResourceBundleInfoPlist(bundle: bundleName, file: file, error))
        }
      }
  }
  
  /// Creates the contents of an app's `Info.plist` file.
  /// - Parameters:
  ///   - appName: The app's name.
  ///   - bundleIdentifier: The app's bundle identifier (e.g. `com.example.HelloWorldApp`).
  ///   - version: The app's version string.
  ///   - category: The app's category.
  ///   - minimumMacOSVersion: The minimum macOS version that the app should run on.
  ///   - extraPlistEntries: Extra entries to insert into `Info.plist`.
  /// - Returns: The generated contents for the `Info.plist` file. If an error occurs, a failure is returned.
  static func createAppInfoPlistContents(
    appName: String,
    bundleIdentifier: String,
    version: String,
    category: String?,
    minimumMacOSVersion: String,
    extraPlistEntries: [String: String]
  ) -> Result<Data, PlistCreatorError> {
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
      "LSMinimumSystemVersion": minimumMacOSVersion,
    ]

    if let category = category {
      entries["LSApplicationCategoryType"] = category
    }
    
    for (key, value) in extraPlistEntries {
      entries[key] = value
    }
    
    return Self.serialize(entries)
  }
  
  /// Creates the contents of a resource bundle's `Info.plist` file.
  /// - Parameters:
  ///   - bundleName: The bundle's name.
  ///   - minimumMacOSVersion: The minimum macOS version that the resource bundle should work on.
  /// - Returns: The generated contents for the `Info.plist` file. If an error occurs, a failure is returned.
  static func createResourceBundleInfoPlistContents(bundleName: String, minimumMacOSVersion: String) -> Result<Data, PlistCreatorError> {
    let bundleIdentifier = bundleName.replacingOccurrences(of: "_", with: "-") + "-resources"
    let entries: [String: Any] = [
      "CFBundleIdentifier": bundleIdentifier,
      "CFBundleInfoDictionaryVersion": "6.0",
      "CFBundleName": bundleName,
      "CFBundlePackageType": "BNDL",
      "CFBundleSupportedPlatforms": ["MacOSX"],
      "LSMinimumSystemVersion": minimumMacOSVersion,
    ]
    
    return Self.serialize(entries)
  }
  
  /// Serializes a plist dictionary into an `xml` format.
  /// - Parameter entries: The dictionary of entries to serialize.
  /// - Returns: The plist dictionary serialized as a string containing xml. If an error occurs, a failure is returned.
  static func serialize(_ entries: [String: Any]) -> Result<Data, PlistCreatorError> {
    do {
      let data = try PropertyListSerialization.data(fromPropertyList: entries, format: .xml, options: 0)
      return .success(data)
    } catch {
      return .failure(.serializationFailed(error))
    }
  }
}
