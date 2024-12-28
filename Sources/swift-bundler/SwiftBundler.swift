import Foundation
import StackOtterArgParser
import Version

/// The root command of Swift Bundler.
struct SwiftBundler: ParsableCommand {
  static let version = Version(3, 0, 0)

  static let configuration = CommandConfiguration(
    commandName: "swift-bundler",
    abstract: "A tool for creating apps from Swift packages.",
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
      ListIdentitiesCommand.self,
    ]
    .filter {
      if Self.host != .macOS {
        // Other non-macOS systems do not support running simulators and identities
        $0 != SimulatorsCommand.self && $0 != ListIdentitiesCommand.self
      } else {
        true
      }
    }
  )

  /// Swift Bundler's git URL. Used when generating Swift packages that depend
  /// on the Swift Bundler runtime or builder API.
  static let gitURL = URL(string: "https://github.com/stackotter/swift-bundler")!

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

  #if os(Linux)
    static let host = Host.linux
  #elseif os(macOS)
    static let host = Host.macOS
  #endif

  enum Host: Hashable, Codable {
    case macOS
    case linux

    var defaultForHostPlatform: Platform {
      switch self {
        case .macOS: .macOS
        case .linux: .linux
      }
    }
  }
}
