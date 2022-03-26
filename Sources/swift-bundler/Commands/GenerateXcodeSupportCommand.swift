import Foundation
import ArgumentParser

struct GenerateXcodeSupportCommand: ParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "generate-xcode-support",
    abstract: "Generate the files required for Xcode to work nicely with a package.")
  
  @Option(
    name: [.customShort("d"), .customLong("directory")],
    help: "The directory containing the package to generate Xcode support files for.",
    transform: URL.init(fileURLWithPath:))
  var packageDirectory: URL?
  
  func run() throws {
    let packageDirectory = packageDirectory ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let configuration = try Configuration.load(fromDirectory: packageDirectory).unwrap()
    
    try XcodeSupportGenerator.generateXcodeSupport(
      for: configuration,
      in: packageDirectory
    ).unwrap()
  }
}
