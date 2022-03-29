import Foundation
import ArgumentParser

/// The subcommand for running an app's postbuild script.
struct PostbuildCommand: ParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "postbuild",
    abstract: "Run a package's postbuild script.")
  
  /// The directory of the package to run the postbuild script of.
  @Option(
    name: [.customLong("directory"), .customShort("d")],
    help: "The directory of the package to run the postbuild script of.",
    transform: URL.init(fileURLWithPath:))
  var packageDirectory: URL?
  
  func run() throws {
    let packageDirectory = packageDirectory ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    try Bundler.postbuild(packageDirectory).unwrap()
  }
}
