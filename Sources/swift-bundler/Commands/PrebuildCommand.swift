import Foundation
import ArgumentParser

/// The subcommand for running an app's prebuild script.
struct PrebuildCommand: ParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "prebuild",
    abstract: "Run a package's prebuild script.")

  /// The directory of the package to run the prebuild script of.
  @Option(
    name: [.customLong("directory"), .customShort("d")],
    help: "The directory of the package to run the prebuild script of.",
    transform: URL.init(fileURLWithPath:))
  var packageDirectory: URL?

  func run() throws {
    let packageDirectory = packageDirectory ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    try Bundler.prebuild(packageDirectory).unwrap()
  }
}
