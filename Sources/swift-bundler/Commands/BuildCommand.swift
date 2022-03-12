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
    let configuration = try Configuration.load(
      fromDirectory: packageDirectory,
      evaluatorContext: .init(packageDirectory: packageDirectory)).unwrap()
    let appConfiguration = try configuration.getAppConfiguration(appName).unwrap()
    
    let outputDirectory = outputDirectory ?? packageDirectory.appendingPathComponent(".build/bundler")
    
    let productsDirectory = try SwiftPackageManager.getDefaultProductsDirectory(
      in: packageDirectory,
      buildConfiguration: buildConfiguration).unwrap()
    
    let bundler = Bundler(.init(
      appConfiguration: appConfiguration,
      buildConfiguration: buildConfiguration,
      packageDirectory: packageDirectory,
      productsDirectory: productsDirectory,
      outputDirectory: outputDirectory,
      appName: appName ?? configuration.apps.first!.key,
      universal: universal))
    
    let buildAndBundle = flatten(
      bundler.prebuild,
      bundler.build,
      bundler.postbuild,
      bundler.bundle)
    
    try buildAndBundle().unwrap()
  }
}
