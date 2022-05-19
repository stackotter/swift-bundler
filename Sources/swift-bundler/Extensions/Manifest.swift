import PackageModel

extension Manifest {
  /// Gets the declared minimum platform version for a specific platform.
  /// - Parameter platform: The platform in question.
  /// - Returns: The platform version if one is declared.
  func platformVersion(for platform: Platform) -> String? {
    let relevantPlatform = platforms.first { manifestPlatform in
      return manifestPlatform.platformName == platform.manifestName
    }
    return relevantPlatform?.version
  }
}
