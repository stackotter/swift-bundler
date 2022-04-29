import Foundation
import Parsing

/// A utility for creating the contents of plist files.
enum PlistCreator {
  /// Creates an app's `Info.plist` file.
  /// - Parameters:
  ///   - file: The URL of the file to create.
  ///   - appName: The name of the app.
  ///   - version: The app's version string.
  ///   - bundleIdentifier: The app's bundle identifier (e.g. `com.example.HelloWorldApp`).
  ///   - category: The app's category.
  ///   - minimumOSVersion: The minimum OS version that the app should run on.
  ///   - extraPlistEntries: Extra entries to insert into `Info.plist`.
  ///   - platform: The platform the app is for.
  /// - Returns: If an error occurs, a failure is returned.
  static func createAppInfoPlist(
    at file: URL,
    appName: String,
    version: String,
    bundleIdentifier: String?,
    category: String?,
    minimumOSVersion: String?,
    extraPlistEntries: [String: String]?,
    platform: Platform
  ) -> Result<Void, PlistCreatorError> {
    createAppInfoPlistContents(
      appName: appName,
      version: version,
      bundleIdentifier: bundleIdentifier,
      category: category,
      minimumOSVersion: minimumOSVersion,
      extraPlistEntries: extraPlistEntries,
      platform: platform
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
  ///   - minimumOSVersion: The minimum OS version that the resource bundle should work on.
  ///   - platform: The platform the bundle is for.
  /// - Returns: If an error occurs, a failure is returned.
  static func createResourceBundleInfoPlist(
    at file: URL,
    bundleName: String,
    minimumOSVersion: String?,
    platform: Platform
  ) -> Result<Void, PlistCreatorError> {
    createResourceBundleInfoPlistContents(
      bundleName: bundleName,
      minimumOSVersion: minimumOSVersion,
      platform: platform
    ).flatMap { contents in
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
  ///   - version: The app's version string.
  ///   - bundleIdentifier: The app's bundle identifier (e.g. `com.example.HelloWorldApp`).
  ///   - category: The app's category.
  ///   - minimumOSVersion: The minimum OS version that the app should run on.
  ///   - extraPlistEntries: Extra entries to insert into `Info.plist`.
  ///   - platform: The platform the app is for.
  /// - Returns: The generated contents for the `Info.plist` file. If an error occurs, a failure is returned.
  static func createAppInfoPlistContents(
    appName: String,
    version: String,
    bundleIdentifier: String?,
    category: String?,
    minimumOSVersion: String?,
    extraPlistEntries: [String: String]?,
    platform: Platform
  ) -> Result<Data, PlistCreatorError> {
    var entries: [String: Any?] = [
      "CFBundleExecutable": appName,
      "CFBundleIconFile": "AppIcon",
      "CFBundleIconName": "AppIcon",
      "CFBundleIdentifier": bundleIdentifier,
      "CFBundleInfoDictionaryVersion": "6.0",
      "CFBundleName": appName,
      "CFBundlePackageType": "APPL",
      "CFBundleShortVersionString": version,
      "CFBundleSupportedPlatforms": ["MacOSX"],
      "LSApplicationCategoryType": category
    ]

    switch platform {
    case .macOS:
      entries["LSMinimumSystemVersion"] = minimumOSVersion
    case .iOS:
      // TODO: Make the produced Info.plist for iOS identical to Xcode's
      entries["MinimumOSVersion"] = minimumOSVersion
    }

    for (key, value) in extraPlistEntries ?? [:] {
      entries[key] = value
    }

    return Self.serialize(entries.compactMapValues { $0 })
  }

  /// Creates the contents of a resource bundle's `Info.plist` file.
  /// - Parameters:
  ///   - bundleName: The bundle's name.
  ///   - minimumOSVersion: The minimum OS version that the resource bundle should work on.
  ///   - platform: The platform the bundle is for.
  /// - Returns: The generated contents for the `Info.plist` file. If an error occurs, a failure is returned.
  static func createResourceBundleInfoPlistContents(
    bundleName: String,
    minimumOSVersion: String?,
    platform: Platform
  ) -> Result<Data, PlistCreatorError> {
    let bundleIdentifier = bundleName.replacingOccurrences(of: "_", with: "-") + "-resources"
    var entries: [String: Any?] = [
      "CFBundleIdentifier": bundleIdentifier,
      "CFBundleInfoDictionaryVersion": "6.0",
      "CFBundleName": bundleName,
      "CFBundlePackageType": "BNDL",
      "CFBundleSupportedPlatforms": ["MacOSX"],
      "LSMinimumSystemVersion": minimumOSVersion
    ]

    switch platform {
    case .macOS:
      entries["LSMinimumSystemVersion"] = minimumOSVersion
    case .iOS:
      // TODO: Make the produced Info.plist for iOS identical to Xcode's
      entries["MinimumOSVersion"] = minimumOSVersion
    }

    return Self.serialize(entries.compactMapValues { $0 })
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
