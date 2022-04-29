import Foundation

protocol Bundler {
  static func bundle(
    appName: String,
    appConfiguration: AppConfiguration,
    packageDirectory: URL,
    productsDirectory: URL,
    outputDirectory: URL,
    isXcodeBuild: Bool,
    universal: Bool
  ) -> Result<Void, Error>
}

func getBundler(for platform: Platform) -> any Bundler.Type {
  switch platform {
    case .macOS:
      return MacOSBundler.self
    case .iOS:
      return IOSBundler.self
  }
}
