import Foundation
import ArgumentParser
import Version

/// The root command of Swift Bundler.
struct SwiftBundler: AsyncParsableCommand {
  static let version = Version(3, 0, 0)

  static let configuration = CommandConfiguration(
    commandName: "swift-bundler",
    abstract: "A tool for creating macOS apps from Swift packages.",
    version: "v" + version.description,
    shouldDisplay: true,
    subcommands: [
      BundleCommand.self,
      RunCommand.self,
      CreateCommand.self,
      ConvertCommand.self,
      MigrateCommand.self,
      SimulatorsCommand.self,
      TemplatesCommand.self,
      GenerateXcodeSupportCommand.self,
      ListIdentitiesCommand.self
    ]
  )

  @Flag(
    name: .shortAndLong,
    help: "Print verbose error messages.")
  var verbose = false

  func validate() throws {
    // A bit of a hack to set the verbosity level whenever the verbose option is set on the root command
    if verbose {
      log.logLevel = .debug
    }
  }
}
