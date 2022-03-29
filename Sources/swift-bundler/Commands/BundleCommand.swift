import Foundation
import ArgumentParser

/// The subcommand for creating app bundles for a package.
struct BundleCommand: ParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "bundle",
    abstract: "Create an app bundle from a package.")
  
  /// The name of the app to build.
  @Argument(
    help: "The name of the app to build.")
  var appName: String?
  
  /// The directory containing the package to build.
  @Option(
    name: [.customShort("d"), .customLong("directory")],
    help: "The directory containing the package to build.",
    transform: URL.init(fileURLWithPath:))
  var packageDirectory: URL?

  /// The build configuration to use
  @Option(
    name: [.customShort("c"), .customLong("config")],
    help: "The build configuration to use (debug|release).",
    transform: {
      SwiftPackageManager.BuildConfiguration.init(rawValue: $0.lowercased()) ?? .debug
    })
  var buildConfiguration = SwiftPackageManager.BuildConfiguration.debug

  /// The directory to output the bundled .app to.
  @Option(
    name: .shortAndLong,
    help: "The directory to output the bundled .app to.",
    transform: URL.init(fileURLWithPath:))
  var outputDirectory: URL?
  
  /// If `true` a universal application will be created (arm64 and x64).
  @Flag(
    name: .shortAndLong,
    help: "Build a universal application (arm64 and x64).")
  var universal = false
  
  /// Whether to skip the build step or not.
  @Flag(
    name: .long,
    help: "Skip the build step.")
  var skipBuild = false
  
  /// The directory containing the built products. Can only be set when `--skip-build` is supplied.
  @Option(
    name: .long,
    help: "The directory containing the built products. Can only be set when `--skip-build` is supplied.",
    transform: URL.init(fileURLWithPath:))
  var productsDirectory: URL?
  
  /// If `true`, treat the products in the products directory as if they were built by Xcode (which is the same as universal builds by SwiftPM). Can only be `true` when ``skipBuild`` is `true`.
  @Flag(
    name: .long,
    help: "Treats the products in the products directory as if they were built by Xcode (which is the same as universal builds by SwiftPM). Can only be set when `--skip-build` is supplied.")
  var builtWithXcode = false
  
  func run() throws {
    let packageDirectory = packageDirectory ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    
    // Validate parameters
    if !skipBuild {
      guard productsDirectory == nil, !builtWithXcode else {
        log.error("`--products-directory` and `--built-with-xcode` are only compatible with `--skip-build`")
        Foundation.exit(1)
      }
    }
    
    let (appName, appConfiguration) = try Self.getAppConfiguration(appName, packageDirectory: packageDirectory).unwrap()
    let outputDirectory = Self.getOutputDirectory(outputDirectory, packageDirectory: packageDirectory)
    
    let productsDirectory = try productsDirectory ?? SwiftPackageManager.getProductsDirectory(
      in: packageDirectory,
      buildConfiguration: buildConfiguration,
      universal: universal).unwrap()
    
    let prebuild = {
      Bundler.prebuild(packageDirectory)
    }
    
    let build = {
      Bundler.build(
        product: appConfiguration.product,
        in: packageDirectory,
        buildConfiguration: buildConfiguration,
        universal: universal)
    }
    
    let postbuild = {
      Bundler.postbuild(packageDirectory)
    }
    
    let bundle = {
      Bundler.bundle(
        appName: appName,
        appConfiguration: appConfiguration,
        packageDirectory: packageDirectory,
        productsDirectory: productsDirectory,
        outputDirectory: outputDirectory,
        isXcodeBuild: builtWithXcode,
        universal: universal)
    }
    
    let task: () -> Result<Void, BundlerError>
    if skipBuild {
      task = bundle
    } else {
      task = flatten(
        prebuild,
        build,
        bundle,
        postbuild)
    }
    
    try task().unwrap()
  }
  
  /// Gets the configuration for the specified app. If no app is specified, the first app is used (unless there are multiple apps, in which case a failure is returned).
  /// - Parameters:
  ///   - appName: The app's name.
  ///   - packageDirectory: The package's root directory.
  /// - Returns: The app's configuration if successful.
  static func getAppConfiguration(_ appName: String?, packageDirectory: URL) -> Result<(name: String, app: AppConfiguration), ConfigurationError> {
    return Configuration.load(fromDirectory: packageDirectory)
      .flatMap { configuration in
        configuration.getAppConfiguration(appName)
      }
  }
  
  /// Unwraps an optional output directory and returns the default output directory if it's `nil`.
  /// - Parameters:
  ///   - outputDirectory: The output directory. Returned as-is if not `nil`.
  ///   - packageDirectory: The root directory of the package.
  /// - Returns: The output directory to use.
  static func getOutputDirectory(_ outputDirectory: URL?, packageDirectory: URL) -> URL {
    return outputDirectory ?? packageDirectory.appendingPathComponent(".build/bundler")
  }
}
