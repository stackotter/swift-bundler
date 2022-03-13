import Foundation
import ArgumentParser

struct BuildCommand: ParsableCommand {
  static var configuration = CommandConfiguration(commandName: "build")
  
  @Argument(
    help: "The name of the app to build")
  var appName: String?
  
  @Option(
    name: [.customShort("d"), .customLong("directory")],
    help: "The directory containing the package to build",
    transform: URL.init(fileURLWithPath:))
  var packageDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

  @Option(
    name: [.customShort("c"), .customLong("config")],
    help: "The build configuration to use (debug|release)",
    transform: {
      SwiftPackageManager.BuildConfiguration.init(rawValue: $0.lowercased()) ?? .debug
    })
  var buildConfiguration = SwiftPackageManager.BuildConfiguration.debug

  @Option(
    name: .shortAndLong,
    help: "The directory to output the bundled .app to",
    transform: URL.init(fileURLWithPath:))
  var outputDirectory: URL?

  @Flag(
    name: .shortAndLong,
    help: "Build a universal application (arm and intel)")
  var universal = false

  func run() throws {
    let (appName, appConfiguration) = try Self.getAppConfiguration(appName, packageDirectory: packageDirectory).unwrap()
    let outputDirectory = Self.getOutputDirectory(outputDirectory, packageDirectory: packageDirectory)
    
    let productsDirectory = try SwiftPackageManager.getDefaultProductsDirectory(
      in: packageDirectory,
      buildConfiguration: buildConfiguration).unwrap()
    
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
    
    let bundle = {
      Bundler.bundle(
        appName: appName,
        appConfiguration: appConfiguration,
        packageDirectory: packageDirectory,
        productsDirectory: productsDirectory,
        outputDirectory: outputDirectory)
    }
    
    let postbuild = {
      Bundler.postbuild(packageDirectory)
    }
    
    let buildAndBundle = flatten(
      prebuild,
      build,
      bundle,
      postbuild)
    
    try buildAndBundle().unwrap()
  }
  
  /// Gets the configuration for the specified app. If no app is specified, the first app is used (unless there are multiple apps, in which case a failure is returned).
  /// - Parameters:
  ///   - appName: The app's name.
  ///   - packageDirectory: The package's root directory.
  /// - Returns: The app's configuration if successful.
  static func getAppConfiguration(_ appName: String?, packageDirectory: URL) -> Result<(name: String, app: AppConfiguration), ConfigurationError> {
    return Configuration.load(
      fromDirectory: packageDirectory,
      evaluatorContext: .init(packageDirectory: packageDirectory)
    ).flatMap { configuration in
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
