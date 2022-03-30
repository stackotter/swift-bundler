import Foundation
import ArgumentParser

/// The subcommand for generating Xcode related support files (i.e. Xcode schemes).
struct GenerateXcodeSupportCommand: ParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "generate-xcode-support",
    abstract: "Generate the files required for Xcode to work nicely with a package.")
  
  /// The root directory of the package to generate Xcode support files for.
  @Option(
    name: [.customShort("d"), .customLong("directory")],
    help: "The root directory of the package to generate Xcode support files for.",
    transform: URL.init(fileURLWithPath:))
  var packageDirectory: URL?
  
  func run() throws {
    let packageDirectory = packageDirectory ?? URL(fileURLWithPath: ".")
    let configuration = try Configuration.load(fromDirectory: packageDirectory).unwrap()
    
    try XcodeSupportGenerator.generateXcodeSupport(
      for: configuration,
      in: packageDirectory
    ).unwrap()

    log.info("Done")
  }
}
