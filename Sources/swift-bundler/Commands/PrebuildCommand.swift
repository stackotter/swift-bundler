import Foundation
import ArgumentParser

struct PrebuildCommand: ParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "prebuild",
    abstract: "Run a package's prebuild script.")
  
  @Option(name: [.customLong("directory"), .customShort("d")], help: "The directory of the package to run the prebuild script of.", transform: URL.init(fileURLWithPath:))
  var packageDirectory: URL?

  func run() throws {
    let packageDirectory = packageDirectory ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    try Bundler.prebuild(packageDirectory).unwrap()
  }
}
