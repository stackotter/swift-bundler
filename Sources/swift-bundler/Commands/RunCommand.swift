import Foundation
import ArgumentParser

struct RunCommand: ParsableCommand {
  static var configuration = CommandConfiguration(commandName: "run")
  
  // MARK: Build and bundle arguments (keep up-to-date with BuildCommand)
  
  @Argument(
    help: "The name of the app to run")
  var appName: String?
  
  @Option(
    name: [.customShort("d"), .customLong("directory")],
    help: "The directory containing the package to run",
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
  
  // MARK: Run arguments
  
  @Flag(
    name: .long,
    help: "Skips the building and bundling steps")
  var skipBuild = false
  
  // MARK: Methods
  
  func run() throws {
    // Remove arguments already parsed by run command
    var arguments = Array(CommandLine.arguments.dropFirst(2))
    arguments.removeAll { $0 == "--skip-build" }
    
    let buildCommand = try BuildCommand.parse(arguments)
    
    if !skipBuild {
      try buildCommand.run()
    }
    
    let (appName, _) = try BuildCommand.getAppConfiguration(
      buildCommand.appName,
      packageDirectory: buildCommand.packageDirectory
    ).unwrap()
    
    let outputDirectory = BuildCommand.getOutputDirectory(
      buildCommand.outputDirectory,
      packageDirectory: buildCommand.packageDirectory)
    
    try Bundler.run(appName: appName, outputDirectory: outputDirectory).unwrap()
  }
}
