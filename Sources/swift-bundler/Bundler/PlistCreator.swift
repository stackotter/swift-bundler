import Foundation
import Parsing

enum PlistError: LocalizedError {
  case unknownPlistEntryType(String)
  case failedToWriteAppInfoPlist(URL, Error)
  case serializationFailed(Error)
}

/// A utility for creating the contents of plist files.
struct PlistCreator {
  /// Creates an app's `Info.plist` file.
  /// - Parameters:
  ///   - file: The URL of the file to create.
  ///   - appName: The name of the app.
  ///   - appConfiguration: The app's configuration.
  func createAppInfoPlist(at file: URL, appName: String, appConfiguration: AppConfiguration) -> Result<Void, PlistError> {
    createAppInfoPlistContents(appName: appName, appConfiguration: appConfiguration)
      .flatMap { contents in
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
  func createResourceBundleInfoPlist(at file: URL, bundleName: String, appConfiguration: AppConfiguration) -> Result<Void, PlistError> {
    createResourceBundleInfoPlistContents(bundleName: bundleName, appConfiguration: appConfiguration)
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
  ///   - appConfiguration: The app's configuration.
  /// - Returns: The generated contents for the `Info.plist` file.
  func createAppInfoPlistContents(appName: String, appConfiguration: AppConfiguration) -> Result<Data, PlistError> {
    var entries: [String: Any] = [
      "CFBundleExecutable": appName,
      "CFBundleIconFile": "AppIcon",
      "CFBundleIconName": "AppIcon",
      "CFBundleIdentifier": appConfiguration.bundleIdentifier,
      "CFBundleInfoDictionaryVersion": "6.0",
      "CFBundleName": appName,
      "CFBundlePackageType": "APPL",
      "CFBundleShortVersionString": appConfiguration.version,
      "CFBundleSupportedPlatforms": ["MacOSX"],
      "LSApplicationCategoryType": appConfiguration.category,
      "LSMinimumSystemVersion": appConfiguration.minMacOSVersion,
    ]
    
    for (key, value) in appConfiguration.extraPlistEntries {
      entries[key] = value
    }
    
    return Self.serialize(entries)
  }
  
  /// Creates the contents of a resource bundle's `Info.plist` file.
  /// - Parameters:
  ///   - bundleName: The bundle's name.
  /// - Returns: The generated contents for the `Info.plist` file.
  func createResourceBundleInfoPlistContents(bundleName: String, appConfiguration: AppConfiguration) -> Result<Data, PlistError> {
    let bundleIdentifier = bundleName.replacingOccurrences(of: "_", with: "-") + "-resources"
    let entries: [String: Any] = [
      "CFBundleIdentifier": bundleIdentifier,
      "CFBundleInfoDictionaryVersion": "6.0",
      "CFBundleName": bundleName,
      "CFBundlePackageType": "BNDL",
      "CFBundleSupportedPlatforms": ["MacOSX"],
      "LSMinimumSystemVersion": appConfiguration.minMacOSVersion,
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
