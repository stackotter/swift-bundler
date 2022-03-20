import Foundation
import ArgumentParser

struct PostbuildCommand: ParsableCommand {
  static var configuration = CommandConfiguration(commandName: "postbuild")
  
  @Option(name: [.customLong("directory"), .customShort("d")], help: "The directory of the package to run the postbuild script of.", transform: URL.init(fileURLWithPath:))
  var packageDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
  
  func run() throws {
    try Bundler.postbuild(packageDirectory).unwrap()
  }
}
