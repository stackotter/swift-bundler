import Foundation
import Parsing

enum PlistError: LocalizedError {
  case unknownPlistEntryType(String)
  case failedToWriteAppInfoPlist(URL, Error)
  case serializationFailed(Error)
}

/// A utility for creating the contents of plist files.
struct PlistCreator {
  /// The contextual information used to generate plist files.
  var context: Context
  
  struct Context {
    var appName: String
    var configuration: AppConfiguration
  }
  
  /// Creates an app's `Info.plist` file.
  /// - Parameter file: The URL of the file to create.
  func createAppInfoPlist(at file: URL) -> Result<Void, PlistError> {
    createAppInfoPlistContents()
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
  /// - Returns: The generated contents for the `Info.plist` file.
  func createAppInfoPlistContents() -> Result<Data, PlistError> {
    var entries: [String: Any] = [
      "CFBundleExecutable": context.appName,
      "CFBundleIconFile": "AppIcon",
      "CFBundleIconName": "AppIcon",
      "CFBundleIdentifier": context.configuration.bundleIdentifier,
      "CFBundleInfoDictionaryVersion": "6.0",
      "CFBundleName": context.appName,
      "CFBundlePackageType": "APPL",
      "CFBundleShortVersionString": context.configuration.version,
      "CFBundleSupportedPlatforms": ["MacOSX"],
      "LSApplicationCategoryType": context.configuration.category,
      "LSMinimumSystemVersion": context.configuration.minMacOSVersion,
    ]
    
    for (key, value) in context.configuration.extraPlistEntries {
      entries[key] = value
    }
    
    return Self.serialize(entries)
  }
  
  func createBundleInfoPlist(bundleIdentifier: String, bundleName: String) -> Result<Data, PlistError> {
    let entries: [String: Any] = [
      "CFBundleIdentifier": bundleIdentifier,
      "CFBundleInfoDictionaryVersion": "6.0",
      "CFBundleName": bundleName,
      "CFBundlePackageType": "BNDL",
      "CFBundleSupportedPlatforms": ["MacOSX"],
      "LSMinimumSystemVersion": context.configuration.minMacOSVersion,
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
