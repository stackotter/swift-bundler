import Foundation

protocol Bundler {
  static func bundle(
    appName: String,
    packageName: String,
    appConfiguration: AppConfiguration,
    packageDirectory: URL,
    productsDirectory: URL,
    outputDirectory: URL,
    isXcodeBuild: Bool,
    universal: Bool,
    standAlone: Bool,
    codesigningIdentity: String?,
    provisioningProfile: URL?,
    platformVersion: String,
    targetingSimulator: Bool
  ) -> Result<Void, Error>
}

func getBundler(for platform: Platform) -> any Bundler.Type {
  switch platform {
    case .macOS:
      return MacOSBundler.self
    case .iOS, .iOSSimulator:
      return IOSBundler.self
    case .visionOS, .visionOSSimulator:
      return VisionOSBundler.self
    case .linux:
      fatalError("Unimplemented")
  }
}
