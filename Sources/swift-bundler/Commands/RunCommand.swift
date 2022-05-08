import Foundation
import ArgumentParser

/// The subcommand for running an app from a package.
struct RunCommand: Command {
  static var configuration = CommandConfiguration(
    commandName: "run",
    abstract: "Run a package as an app.")

  // MARK: Build and bundle arguments (keep up-to-date with BundleCommand)

  /// The name of the app to build.
  @Argument(
    help: "The name of the app to run.")
  var appName: String?

  /// The directory containing the package to build.
  @Option(
    name: [.customShort("d"), .customLong("directory")],
    help: "The directory containing the package to build.",
    transform: URL.init(fileURLWithPath:))
  var packageDirectory: URL?

  /// The directory to output the bundled .app to.
  @Option(
    name: .shortAndLong,
    help: "The directory to output the bundled .app to.",
    transform: URL.init(fileURLWithPath:))
  var outputDirectory: URL?

  /// The directory containing the built products. Can only be set when `--skip-build` is supplied.
  @Option(
    name: .long,
    help: "The directory containing the built products. Can only be set when `--skip-build` is supplied.",
    transform: URL.init(fileURLWithPath:))
  var productsDirectory: URL?

  /// The build configuration to use.
  @Option(
    name: [.customShort("c"), .customLong("configuration")],
    help: "The build configuration to use \(BuildConfiguration.possibleValuesString).",
    transform: {
      guard let configuration = BuildConfiguration.init(rawValue: $0.lowercased()) else {
        throw CLIError.invalidBuildConfiguration($0)
      }
      return configuration
    })
  var buildConfiguration = BuildConfiguration.debug

  /// The architectures to build for.
  @Option(
    name: [.customShort("a"), .customLong("arch")],
    parsing: .singleValue,
    help: {
      let possibleValues = BuildArchitecture.possibleValuesString
      let defaultValue = BuildArchitecture.current.rawValue
      return "The architectures to build for \(possibleValues). (default: [\(defaultValue)])"
    }(),
    transform: {
      guard let arch = BuildArchitecture.init(rawValue: $0) else {
        throw CLIError.invalidBuildConfiguration($0)
      }
      return arch
    })
  var architectures: [BuildArchitecture] = []

  /// The platform to build for (incompatible with `--arch`).
  @Option(
    name: .shortAndLong,
    help: {
      let possibleValues = Platform.possibleValuesString
      return "The platform to build for \(possibleValues). Incompatible with `--arch`."
    }(),
    transform: {
      guard let platform = Platform.init(rawValue: $0) else {
        throw CLIError.invalidPlatform($0)
      }
      return platform
    })
  var platform = Platform.macOS

  /// A codesigning identity to use.
  @Option(
    name: .customLong("identity"),
    help: "The identity to use for codesigning")
  var identity: String?

  /// A provisioing profile to use.
  @Option(
    name: .customLong("provisioning-profile"),
    help: "The provisioning profile to embed in the app (only applicable to iOS).",
    transform: URL.init(fileURLWithPath:))
  var provisioningProfile: URL?

  /// If `true`, the application will be codesigned.
  @Flag(
    name: .customLong("codesign"),
    help: "Codesign the application (use `--identity` to select the identity).")
  var shouldCodesign = false

  /// If `true` a universal application will be created (arm64 and x86_64).
  @Flag(
    name: .shortAndLong,
    help: "Build a universal application. Equivalent to '--arch arm64 --arch x86_64'.")
  var universal = false

  // MARK: Run arguments

  /// If `true`, the building and bundling step is skipped.
  @Flag(
    name: .long,
    help: "Skips the building and bundling steps.")
  var skipBuild = false

  // MARK: Methods

  func wrappedRun() throws {
    // Remove arguments already parsed by run command
    var arguments = Array(CommandLine.arguments.dropFirst(2))
    arguments.removeAll { $0 == "--skip-build" || $0 == "-v" || $0 == "--verbose" }

    let buildCommand = try BundleCommand.parse(arguments)

    let packageDirectory = buildCommand.packageDirectory ?? URL(fileURLWithPath: ".")

    if !skipBuild {
      buildCommand.run()
    }

    let (appName, _) = try BundleCommand.getAppConfiguration(
      buildCommand.appName,
      packageDirectory: packageDirectory
    ).unwrap()

    let outputDirectory = BundleCommand.getOutputDirectory(
      buildCommand.outputDirectory,
      packageDirectory: packageDirectory)

    try Runner.run(
      bundle: outputDirectory.appendingPathComponent("\(appName).app"),
      platform: platform
    ).unwrap()
  }
}
