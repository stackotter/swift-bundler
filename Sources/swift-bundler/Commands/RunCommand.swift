import Foundation
import StackOtterArgParser

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

  @Option(
    name: [.customLong("simulator")],
    help: "A simulator name, id or search term to select the target simulator (e.g. 'iPhone 8' or 'Apple Vision Pro').")
  var simulatorSearchTerm: String?

  /// If `true`, the building and bundling step is skipped.
  @Flag(
    name: .long,
    help: "Skips the building and bundling steps.")
  var skipBuild = false

  /// Command line arguments that get passed through to the app.
  @Argument(
    parsing: .captureForPassthrough,
    help: "Command line arguments to pass through to the app.")
  var passThroughArguments: [String] = []

  // MARK: Methods

  func wrappedRun() async throws {
    // Validate arguments
    if !arguments.platform.isSimulator && simulatorSearchTerm != nil {
      log.error("'--simulator' can only be used when the selected platform is a simulator")
      Foundation.exit(1)
    }

    // Load configuration
    let packageDirectory = arguments.packageDirectory ?? URL(fileURLWithPath: ".")

    let outputDirectory = BundleCommand.getOutputDirectory(
      arguments.outputDirectory,
      packageDirectory: packageDirectory
    )

    let (appName, appConfiguration) = try BundleCommand.getAppConfiguration(
      arguments.appName,
      packageDirectory: packageDirectory,
      customFile: arguments.configurationFileOverride
    ).unwrap()

    // Get the device to run on
    let device = try Self.getDevice(
      for: arguments.platform, simulatorSearchTerm: simulatorSearchTerm)

    let bundleCommand = BundleCommand(
      arguments: _arguments, skipBuild: false, builtWithXcode: false
    )

    if !skipBuild {
      await bundleCommand.run()
    }

    try Runner.run(
      bundle: outputDirectory.appendingPathComponent("\(appName).app"),
      bundleIdentifier: appConfiguration.identifier,
      device: device,
      arguments: passThroughArguments,
      environmentFile: environmentFile
    ).unwrap()
  }

  static func getDevice(for platform: Platform, simulatorSearchTerm: String?) throws -> Device {
    switch platform {
      case .macOS:
        return .macOS
      case .iOS:
        return .iOS
      case .visionOS:
        return .visionOS
      case .linux:
        return .linux
      case .iOSSimulator, .visionOSSimulator:
        // TODO: Refactor this into a separate function.
        if let searchTerm = simulatorSearchTerm {
          // Get matching simulators
          let simulators = try SimulatorManager.listAvailableSimulators(searchTerm: searchTerm)
            .unwrap().sorted { first, second in
              // Put booted simulators first and sort by name length
              if first.state == .shutdown && second.state == .booted {
                return false
              } else if first.name.count > second.name.count {
                return false
              } else {
                return true
              }
            }

          guard let simulator = simulators.first else {
            log.error(
              "Search term '\(searchTerm)' did not match any simulators. To list available simulators, use the following command:"
            )

            Output {
              ""
              ExampleCommand("swift bundler simulators list")
            }.show()

            Foundation.exit(1)
          }

          if simulators.count > 1 {
            log.info("Found multiple matching simulators, using '\(simulator.name)'")
          }

          return platform == .iOSSimulator ? .iOSSimulator(id: simulator.id) : .visionOSSimulator(id: simulator.id)
        } else {
          let allSimulators = try SimulatorManager.listAvailableSimulators().unwrap()

          // If an iOS simulator is booted, use that
          if allSimulators.contains(where: { $0.state == .booted }) {
            return platform == .iOSSimulator ? .iOSSimulator(id: "booted") : .visionOSSimulator(id: "booted")
          } else {
            // swiftlint:disable:next line_length
            log.error(
              "To run on the iOS simulator, you must either use the '--simulator' option or have a valid simulator running already. To list available simulators, use the following command:"
            )

            Output {
              ExampleCommand("swift bundler simulators list")
            }.show()

            Foundation.exit(1)
          }
        }
    }
  }
}
