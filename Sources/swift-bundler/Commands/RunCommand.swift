import Foundation
import ArgumentParser

/// The subcommand for running an app from a package.
struct RunCommand: ParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "run",
    abstract: "Run a package as an app.")
  
  // MARK: Build and bundle arguments (keep up-to-date with BuildCommand)
  
  @Argument(
    help: "The name of the app to run.")
  var appName: String?
  
  @Option(
    name: [.customShort("d"), .customLong("directory")],
    help: "The directory containing the package to run.",
    transform: URL.init(fileURLWithPath:))
  var packageDirectory: URL?
  
  @Option(
    name: [.customShort("c"), .customLong("config")],
    help: "The build configuration to use (debug|release).",
    transform: {
      SwiftPackageManager.BuildConfiguration.init(rawValue: $0.lowercased()) ?? .debug
    })
  var buildConfiguration = SwiftPackageManager.BuildConfiguration.debug
  
  @Option(
    name: .shortAndLong,
    help: "The directory to output the bundled .app to.",
    transform: URL.init(fileURLWithPath:))
  var outputDirectory: URL?
  
  @Flag(
    name: .shortAndLong,
    help: "Build a universal application (arm and intel).")
  var universal = false
  
  // MARK: Run arguments
  
  @Flag(
    name: .long,
    help: "Skips the building and bundling steps.")
  var skipBuild = false
  
  // MARK: Methods
  
  func run() throws {
    // Remove arguments already parsed by run command
    var arguments = Array(CommandLine.arguments.dropFirst(2))
    arguments.removeAll { $0 == "--skip-build" }
    
    let buildCommand = try BundleCommand.parse(arguments)
    
    let packageDirectory = buildCommand.packageDirectory ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    
    if !skipBuild {
      try buildCommand.run()
    }
    
    let (appName, _) = try BundleCommand.getAppConfiguration(
      buildCommand.appName,
      packageDirectory: packageDirectory
    ).unwrap()
    
    let outputDirectory = BundleCommand.getOutputDirectory(
      buildCommand.outputDirectory,
      packageDirectory: packageDirectory)
    
    try Bundler.run(appName: appName, outputDirectory: outputDirectory).unwrap()
  }
}
