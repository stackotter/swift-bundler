import Foundation

/// The parsed output of an executed `Package.swift` file.
struct PackageManifest: Decodable {
  struct Package: Decodable {
    struct PlatformName: Decodable {
      var name: String
    }

    struct Platform: Decodable {
      var platform: PlatformName
      var version: String
    }

    var name: String
    var platforms: [Platform]?
  }

  var package: Package

  var displayName: String {
    return package.name
  }

  var platforms: [(name: String, version: String)] {
    return package.platforms?.map { platform in
      return (platform.platform.name, platform.version)
    } ?? []
  }

  func platformVersion(for platform: Platform) -> String? {
    // TODO: Refactor so that bundler doesn't even attempt to get the platform version of Linux
    if platform == .linux {
      return "0.0"
    }
    return platforms.first(where: { (name, _) in
      return platform.manifestName == name
    })?.version
  }
}
