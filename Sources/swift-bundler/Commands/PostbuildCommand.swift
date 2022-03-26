import Foundation
import ArgumentParser

struct PostbuildCommand: ParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "postbuild",
    abstract: "Run a package's postbuild script.")
  
  @Option(name: [.customLong("directory"), .customShort("d")], help: "The directory of the package to run the postbuild script of.", transform: URL.init(fileURLWithPath:))
  var packageDirectory: URL?
  
  func run() throws {
    let packageDirectory = packageDirectory ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    try Bundler.postbuild(packageDirectory).unwrap()
  }
}
