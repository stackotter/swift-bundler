import Foundation

protocol Bundler {
  associatedtype Context
  associatedtype Error: LocalizedError

  /// Bundles an app from a package's built products directory.
  /// - Parameters:
  ///   - context: The general context passed to all bundlers.
  ///   - additionalContext: The bundler-specific context for this bundler.
  static func bundle(
    _ context: BundlerContext,
    _ additionalContext: Context
  ) -> Result<Void, Error>
}

struct BundlerContext {
  /// The name to give the bundled app.
  var appName: String
  /// The name of the package.
  var packageName: String
  /// The app's configuration.
  var appConfiguration: AppConfiguration

  /// The root directory of the package containing the app.
  var packageDirectory: URL
  /// The directory containing the products from the build step.
  var productsDirectory: URL
  /// The directory to output the app into.
  var outputDirectory: URL

  /// The platform that the app's product was built for.
  var platform: Platform

  /// The app's main built executable file.
  var executableArtifact: URL {
    productsDirectory.appendingPathComponent(appName)
  }
}

func getBundler(for platform: Platform) -> any Bundler.Type {
  switch platform {
    case .macOS:
      return DarwinBundler.self
    case .iOS, .iOSSimulator:
      return DarwinBundler.self
    case .tvOS, .tvOSSimulator:
      return DarwinBundler.self
    case .visionOS, .visionOSSimulator:
      return DarwinBundler.self
    case .linux:
      return AppImageBundler.self
  }
}
