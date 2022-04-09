import Foundation
import ArgumentParser

/// The subcommand for generating Xcode related support files (i.e. Xcode schemes).
struct GenerateXcodeSupportCommand: Command {
  static var configuration = CommandConfiguration(
    commandName: "generate-xcode-support",
    abstract: "Generate the files required for Xcode to work nicely with a package.",
    discussion: "This requires Swift Bundler to be installed at '/opt/swift-bundler/swift-bundler'")

  /// The root directory of the package to generate Xcode support files for.
  @Option(
    name: [.customShort("d"), .customLong("directory")],
    help: "The root directory of the package to generate Xcode support files for.",
    transform: URL.init(fileURLWithPath:))
  var packageDirectory: URL?

  func wrappedRun() throws {
    let elapsed = try Stopwatch.time {
      let packageDirectory = packageDirectory ?? URL(fileURLWithPath: ".")
      let configuration = try Configuration.load(fromDirectory: packageDirectory).unwrap()

      try XcodeSupportGenerator.generateXcodeSupport(
        for: configuration,
        in: packageDirectory
      ).unwrap()
    }

    log.info("Done in \(elapsed.secondsString).")

    print(Output {
      ""
      Section("Opening your project in Xcode") {
        ExampleCommand("open Package.swift -a /Applications/Xcode.app")
        ""
        "The '-a /Applications/Xcode.app' option is only required if your default app isn't Xcode"
      }
    })
  }
}
