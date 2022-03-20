import Foundation
import ArgumentParser

struct GenerateXcodeSupportCommand: ParsableCommand {
  static var configuration = CommandConfiguration(commandName: "generate-xcode-support")
  
  @Option(
    name: [.customShort("d"), .customLong("directory")],
    help: "The directory containing the package to generate Xcode support files for.",
    transform: URL.init(fileURLWithPath:))
  var packageDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
  
  func run() throws {
    let configuration = try Configuration.load(fromDirectory: packageDirectory).unwrap()
    
    try XcodeSupportGenerator.generateXcodeSupport(
      for: configuration,
      in: packageDirectory
    ).unwrap()
  }
}
