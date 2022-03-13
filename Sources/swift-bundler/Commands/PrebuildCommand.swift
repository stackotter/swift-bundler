import Foundation
import ArgumentParser

struct PrebuildCommand: ParsableCommand {
  static var configuration = CommandConfiguration(commandName: "prebuild")
  
  @Option(name: [.customLong("directory"), .customShort("d")], help: "The directory of the package to run the prebuild script of", transform: URL.init(fileURLWithPath:))
  var packageDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

  func run() throws {
    try Bundler.prebuild(packageDirectory).unwrap()
  }
}
