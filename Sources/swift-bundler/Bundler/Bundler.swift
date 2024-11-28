import Foundation

protocol Bundler {
  associatedtype Context
  associatedtype Error: LocalizedError

  /// Computes the bundler's own context given the generic bundler context
  /// and Swift bundler's parsed command-line arguments, options, and flags.
  ///
  /// This step is split out from ``bundle(_:_:)`` and ``intendedOutput(in:_:)``
  /// to maximise the reusability of bundlers. If every bundler required the
  /// full set of command-line arguments to do anything at all then they'd all
  /// be pretty cumbersome to use in non-command-line contexts. Additionally,
  /// this design allows for bundlers to expose niche configuration options
  /// for non-command-line users to use while still keeping command-line code
  /// generic (i.e. no bundlers should require special treatment).
  static func computeContext(
    context: BundlerContext,
    command: BundleCommand,
    manifest: PackageManifest
  ) -> Result<Context, Error>

  /// Bundles an app from a package's built products directory.
  /// - Parameters:
  ///   - context: The general context passed to all bundlers.
  ///   - additionalContext: The bundler-specific context for this bundler.
  /// - Returns: The URL of the produced app bundle on success.
  static func bundle(
    _ context: BundlerContext,
    _ additionalContext: Context
  ) -> Result<BundlerOutputStructure, Error>

  /// Returns a description of the files that would be produced if
  /// ``Bundler/bundle(_:_:)`` were to get called with the provided context.
  static func intendedOutput(
    in context: BundlerContext,
    _ additionalContext: Context
  ) -> BundlerOutputStructure
}

extension Bundler where Context == Void {
  static func computeContext(
    context: BundlerContext,
    command: BundleCommand,
    manifest: PackageManifest
  ) -> Result<Void, Error> {
    .success()
  }
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
  /// The platform version getting built for.
  var platformVersion: String?

  /// The app's main built executable file.
  var executableArtifact: URL {
    productsDirectory.appendingPathComponent(appName)
  }
}

/// Describes the basic structure of a bundler's output. Shouldn't describe
/// intermediate files, only the useful final outputs of the bundler.
struct BundlerOutputStructure {
  /// The bundle itself.
  var bundle: URL
  /// The actual executable file to run when the user instructs Swift Bundler
  /// to run the app. If `nil`, it's assumed that the bundler doesn't support
  /// running.
  var executable: URL?
  /// Any other files produced that might be useful wnen distributing the app,
  /// e.g. a `.desktop` file on Linux.
  var additionalOutputs: [URL] = []
}

/// A variation on ``BundlerOutputStructure`` validated as runnable, guarantees
/// that the output contains an executable (or at least claims it does).
struct RunnableBundlerOutputStructure {
  /// The bundle itself.
  var bundle: URL
  /// The actual executable file to run when the user instructs Swift Bundler
  /// to run the app.
  var executable: URL

  /// Validates a bundler's output for 'runnability' (i.e. it claims to have
  /// produced an executable).
  init?(_ output: BundlerOutputStructure) {
    guard let executable = output.executable else {
      return nil
    }
    bundle = output.bundle
    self.executable = executable
  }
}

/// Gets the bundler to use when targeting the specified platform.
func getBundler(for platform: Platform) -> any Bundler.Type {
  switch platform {
    case .macOS, .iOS, .iOSSimulator, .tvOS, .tvOSSimulator, .visionOS, .visionOSSimulator:
      return DarwinBundler.self
    case .linux:
      return AppImageBundler.self
  }
}
