import Foundation
import ArgumentParser
import TOMLKit

struct BuildCommand: ParsableCommand {
  static var configuration = CommandConfiguration(commandName: "build")
  
  @Option(
    name: [.customLong("directory"), .customShort("d")],
    help: "The directory containing the package to be bundled",
    transform: URL.init(fileURLWithPath:))
  var packageDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

  @Option(
    name: [.customShort("c"), .customLong("config")],
    help: "The build configuration to use (debug|release)",
    transform: {
      Bundler.BuildConfiguration.init(rawValue: $0.lowercased()) ?? .debug
    })
  var buildConfiguration = Bundler.BuildConfiguration.debug

  @Option(
    name: .shortAndLong,
    help: "The directory to output the bundled .app to",
    transform: URL.init(fileURLWithPath:))
  var outputDirectory: URL?

  @Flag(
    name: [.customShort("u"), .customLong("universal")],
    help: "Build a universal application (arm and intel)")
  var universal = false

  func run() throws {
    let configuration = AppConfiguration(
      target: "HelloWorld",
      version: "0.1.0",
      category: "example",
      bundleIdentifier: "dev.stackotter.test-app",
      minMacOSVersion: "11.0",
      plistEntries: [:])
    
    let outputDirectory = outputDirectory ?? packageDirectory.appendingPathComponent(".build/bundler")
    let productsDirectory = packageDirectory.appendingPathComponent(".build/\(buildConfiguration)")
    
    let bundler = Bundler(.init(
      appConfiguration: configuration,
      buildConfiguration: buildConfiguration,
      packageDirectory: packageDirectory,
      productsDirectory: productsDirectory,
      outputDirectory: outputDirectory,
      appName: "HelloWorldApp",
      universal: universal))
    
    try bundler.prebuild()
    try bundler.build()
    try bundler.postbuild()
    try bundler.bundle()
  }
}
