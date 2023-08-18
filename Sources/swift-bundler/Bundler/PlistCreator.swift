import Foundation
import Parsing

/// A utility for creating the contents of plist files.
enum PlistCreator {
  /// Creates an app's `Info.plist` file.
  /// - Parameters:
  ///   - file: The URL of the file to create.
  ///   - appName: The name of the app.
  ///   - configuration: The app's configuration.
  ///   - platform: The platform the app is for.
  ///   - platformVersion: The minimum platform version that the app should run on.
  /// - Returns: If an error occurs, a failure is returned.
  static func createAppInfoPlist(
    at file: URL,
    appName: String,
    configuration: AppConfiguration,
    platform: Platform,
    platformVersion: String
  ) -> Result<Void, PlistCreatorError> {
    createAppInfoPlistContents(
      appName: appName,
      configuration: configuration,
      platform: platform,
      platformVersion: platformVersion
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
  ///   - platformVersion: The minimum platform version that the app should run on.
  /// - Returns: If an error occurs, a failure is returned.
  static func createResourceBundleInfoPlist(
    at file: URL,
    bundleName: String,
    platform: Platform,
    platformVersion: String
  ) -> Result<Void, PlistCreatorError> {
    createResourceBundleInfoPlistContents(
      bundleName: bundleName,
      platform: platform,
      platformVersion: platformVersion
    ).flatMap { contents in
      do {
        try contents.write(to: file)
        return .success()
      } catch {
        return .failure(
          .failedToWriteResourceBundleInfoPlist(bundle: bundleName, file: file, error))
      }
    }
  }

  /// Creates the contents of an app's `Info.plist` file.
  /// - Parameters:
  ///   - appName: The app's name.
  ///   - configuration: The app's configuration.
  ///   - platform: The platform the app is for.
  ///   - platformVersion: The minimum platform version that the app should run on.
  /// - Returns: The generated contents for the `Info.plist` file. If an error occurs, a failure is returned.
  static func createAppInfoPlistContents(
    appName: String,
    configuration: AppConfiguration,
    platform: Platform,
    platformVersion: String
  ) -> Result<Data, PlistCreatorError> {
    var entries: [String: Any?] = [
      "CFBundleDevelopmentRegion": "en",
      "CFBundleExecutable": appName,
      "CFBundleIconFile": "AppIcon",
      "CFBundleIconName": "AppIcon",
      "CFBundleIdentifier": configuration.identifier,
      "CFBundleInfoDictionaryVersion": "6.0",
      "CFBundleName": appName,
      "CFBundlePackageType": "APPL",
      "CFBundleShortVersionString": configuration.version,
      "CFBundleVersion": configuration.version,
      "LSApplicationCategoryType": configuration.category,
    ]

    switch platform {
      case .macOS:
        entries["LSMinimumSystemVersion"] = platformVersion
        entries["CFBundleSupportedPlatforms"] = ["MacOSX"]
      case .iOS, .iOSSimulator:
        entries["MinimumOSVersion"] = platformVersion
        entries["CFBundleSupportedPlatforms"] = ["iPhoneOS"]
        entries["UILaunchScreen"] = [String: Any]()
      case .visionOS, .visionOSSimulator:
        entries["MinimumOSVersion"] = platformVersion
        entries["CFBundleSupportedPlatforms"] = ["XROS"]
        entries["UISceneConfigurations"] = [String: Any]()
      case .linux:
        break
    }

    for (key, value) in configuration.plist ?? [:] {
      entries[key] = value.value
    }

    return Self.serialize(entries.compactMapValues { $0 })
  }

  /// Creates the contents of a resource bundle's `Info.plist` file.
  /// - Parameters:
  ///   - bundleName: The bundle's name.
  ///   - platform: The platform the bundle is for.
  ///   - platformVersion: The minimum platform version that the app should run on.
  /// - Returns: The generated contents for the `Info.plist` file. If an error occurs, a failure is returned.
  static func createResourceBundleInfoPlistContents(
    bundleName: String,
    platform: Platform,
    platformVersion: String
  ) -> Result<Data, PlistCreatorError> {
    let bundleIdentifier = bundleName.replacingOccurrences(of: "_", with: "-") + "-resources"
    var entries: [String: Any?] = [
      "CFBundleIdentifier": bundleIdentifier,
      "CFBundleInfoDictionaryVersion": "6.0",
      "CFBundleName": bundleName,
      "CFBundlePackageType": "BNDL",
    ]

    switch platform {
      case .macOS:
        entries["LSMinimumSystemVersion"] = platformVersion
        entries["CFBundleSupportedPlatforms"] = ["MacOSX"]
      case .iOS, .iOSSimulator:
        // TODO: Make the produced Info.plist for iOS identical to Xcode's
        entries["MinimumOSVersion"] = platformVersion
        entries["CFBundleSupportedPlatforms"] = ["iPhoneOS"]
      case .visionOS, .visionOSSimulator:
        // TODO: Make the produced Info.plist for visionOS identical to Xcode's
        entries["MinimumOSVersion"] = platformVersion
        entries["CFBundleSupportedPlatforms"] = ["XROS"]
      case .linux:
        break
    }

    return Self.serialize(entries.compactMapValues { $0 })
  }

  /// Serializes a plist dictionary into an `xml` format.
  /// - Parameter entries: The dictionary of entries to serialize.
  /// - Returns: The plist dictionary serialized as a string containing xml. If an error occurs, a failure is returned.
  static func serialize(_ entries: [String: Any]) -> Result<Data, PlistCreatorError> {
    do {
      let data = try PropertyListSerialization.data(
        fromPropertyList: entries, format: .xml, options: 0)
      return .success(data)
    } catch {
      return .failure(.serializationFailed(error))
    }
  }
}
