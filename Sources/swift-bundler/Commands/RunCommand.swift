import Foundation
import ArgumentParser

/// The subcommand for running an app from a package.
struct RunCommand: AsyncCommand {
  static var configuration = CommandConfiguration(
    commandName: "run",
    abstract: "Run a package as an app."
  )

  /// Arguments in common with the bundle command.
  @OptionGroup
  var arguments: BundleArguments

  /// A file containing environment variables to pass to the app.
  @Option(
    name: [.customLong("env")],
    help: "A file containing environment variables to pass to the app.",
    transform: URL.init(fileURLWithPath:))
  var environmentFile: URL?

  /// If `true`, the building and bundling step is skipped.
  @Flag(
    name: .long,
    help: "Skips the building and bundling steps.")
  var skipBuild = false

  // MARK: Methods

  func wrappedRun() async throws {
    let packageDirectory = arguments.packageDirectory ?? URL(fileURLWithPath: ".")

    let outputDirectory = BundleCommand.getOutputDirectory(
      arguments.outputDirectory,
      packageDirectory: packageDirectory
    )

    let (appName, appConfiguration) = try BundleCommand.getAppConfiguration(
      arguments.appName,
      packageDirectory: packageDirectory
    ).unwrap()

    let platform = try BundleCommand.parsePlatform(arguments.platform, appConfiguration: appConfiguration)

    let bundleCommand = BundleCommand(arguments: _arguments, builtWithXcode: false)

    if !skipBuild {
      await bundleCommand.run()
    }

    try Runner.run(
      bundle: outputDirectory.appendingPathComponent("\(appName).app"),
      platform: platform,
      environmentFile: environmentFile
    ).unwrap()
  }
}
