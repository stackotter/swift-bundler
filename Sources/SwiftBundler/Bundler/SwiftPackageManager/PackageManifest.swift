import Foundation

/// The parsed output of an executed `Package.swift` file.
struct PackageManifest: Decodable {
  struct VersionedPlatform: Decodable {
    var name: String
    var version: String
  }

  var name: String
  var platforms: [VersionedPlatform]?

  func platformVersion(for os: AppleOS) -> String? {
    platforms?.first { platform in
      return os.manifestName == platform.name
    }?.version
  }
}
