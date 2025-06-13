import ArgumentParser
import Foundation
import Version

/// The root command of Swift Bundler.
public struct SwiftBundler: AsyncParsableCommand {
  public static let version = Version(3, 0, 0)

  public static let configuration = CommandConfiguration(
    commandName: "swift-bundler",
    abstract: "A tool for creating apps from Swift packages.",
    version: "v" + version.description,
    shouldDisplay: true,
    subcommands: [
      BundleCommand.self,
      RunCommand.self,
      CleanCommand.self,
      CreateCommand.self,
      ConvertCommand.self,
      MigrateCommand.self,
      DevicesCommand.self,
      SimulatorsCommand.self,
      TemplatesCommand.self,
      GenerateXcodeSupportCommand.self,
      ListIdentitiesCommand.self,
    ]
  )

  /// Swift Bundler's git URL. Used when generating Swift packages that depend
  /// on the Swift Bundler runtime or builder API.
  public static let gitURL = URL(string: "https://github.com/stackotter/swift-bundler")!

  @Flag(
    name: .shortAndLong,
    help: "Print verbose error messages.")
  public var verbose = false

  public func validate() throws {
    // A bit of a hack to set the verbosity level whenever the verbose option is set on the root command
    if verbose {
      log.logLevel = .debug
    }
  }

  public init() {
    self._verbose = Flag(wrappedValue: false)
  }
}
