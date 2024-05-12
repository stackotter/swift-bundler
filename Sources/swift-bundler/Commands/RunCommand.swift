import Foundation
import HotReloadingProtocol
import Socket
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
    help:
      "A simulator name, id or search term to select the target simulator (e.g. 'iPhone 8' or 'Apple Vision Pro')."
  )
  var simulatorSearchTerm: String?

  /// If `true`, the building and bundling step is skipped.
  @Flag(
    name: .long,
    help: "Skips the building and bundling steps.")
  var skipBuild = false

  /// If `true`, the app gets rebuilt whenever code changes occur, and a hot reloading server is
  /// hosted in the background to notify the running app of the new build.
  @Flag(name: .long, help: "Enables hot reloading.")
  var hot = false

  /// Command line arguments that get passed through to the app.
  @Argument(
    parsing: .captureForPassthrough,
    help: "Command line arguments to pass through to the app.")
  var passThroughArguments: [String] = []

  // MARK: Methods

  func wrappedRun() async throws {
    // Validate arguments
    guard arguments.platform.isSimulator || simulatorSearchTerm == nil else {
      log.error("'--simulator' can only be used when the selected platform is a simulator")
      Foundation.exit(1)
    }

    guard !(skipBuild && hot) else {
      log.error("'--skip-build' is incompatible with '--hot' (nonsensical)")
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
      for: arguments.platform,
      simulatorSearchTerm: simulatorSearchTerm
    )

    let bundleCommand = BundleCommand(
      arguments: _arguments,
      skipBuild: false,
      builtWithXcode: false
    )

    if !skipBuild {
      await bundleCommand.run()
    }

    let bundle: URL
    if device == .linux {
      bundle = outputDirectory.appendingPathComponent("\(appName).AppImage")
    } else {
      bundle = outputDirectory.appendingPathComponent("\(appName).app")
    }

    let environmentVariables =
      try environmentFile.map { file in
        try Runner.loadEnvironmentVariables(from: file).unwrap()
      } ?? [:]

    if hot {
      let port: UInt16 = 7979
      let hotReloadingVariables = [
        "SWIFT_BUNDLER_HOT_RELOADING": "1",
        "SWIFT_BUNDLER_SERVER": "127.0.0.1:\(port)",
      ]

      let socket = try await Socket.init(
        IPv4Protocol.tcp,
        bind: IPv4SocketAddress(address: .any, port: port)
      )
      try await socket.listen()

      Task {
        var client = try await socket.accept()
        log.info("Received connection from runtime")
        let packet = try await Packet.read(from: &client)
        log.info("Received packet from client: \(packet)")
        try await Packet.pong.write(to: &client)
      }

      // TODO: Avoid loading manifest twice
      log.info("Building 'lib\(appConfiguration.product).dylib'")
      let manifest = try await SwiftPackageManager.loadPackageManifest(from: packageDirectory)
        .unwrap()

      guard let platformVersion = manifest.platformVersion(for: arguments.platform) else {
        let manifestFile = packageDirectory.appendingPathComponent("Package.swift")
        throw CLIError.failedToGetPlatformVersion(
          platform: arguments.platform,
          manifest: manifestFile
        )
      }

      let architectures = bundleCommand.getArchitectures(platform: bundleCommand.arguments.platform)
      let dylibFile = try SwiftPackageManager.buildExecutableAsDylib(
        product: appConfiguration.product,
        packageDirectory: packageDirectory,
        configuration: arguments.buildConfiguration,
        architectures: architectures,
        platform: arguments.platform,
        platformVersion: platformVersion
      ).unwrap()
      log.info("Successfully built dylib to '\(dylibFile.relativeString)'")

      try Runner.run(
        bundle: bundle,
        bundleIdentifier: appConfiguration.identifier,
        device: device,
        arguments: passThroughArguments,
        environmentVariables: environmentVariables.merging(
          hotReloadingVariables, uniquingKeysWith: { x, _ in x }
        )
      ).unwrap()
    } else {
      try Runner.run(
        bundle: bundle,
        bundleIdentifier: appConfiguration.identifier,
        device: device,
        arguments: passThroughArguments,
        environmentVariables: environmentVariables
      ).unwrap()
    }
  }

  static func getDevice(for platform: Platform, simulatorSearchTerm: String?) throws -> Device {
    switch platform {
      case .macOS:
        return .macOS
      case .iOS:
        return .iOS
      case .visionOS:
        return .visionOS
      case .tvOS:
        return .tvOS
      case .linux:
        return .linux
      case .iOSSimulator, .visionOSSimulator, .tvOSSimulator:
        // TODO: Refactor this whole case block into a separate function.
        let device: (String) -> Device
        switch platform {
          case .iOSSimulator:
            device = Device.iOSSimulator
          case .visionOSSimulator:
            device = Device.visionOSSimulator
          case .tvOSSimulator:
            device = Device.tvOSSimulator
          default:
            fatalError("Unreachable (supposedly)")
        }
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

          return device(simulator.id)
        } else {
          let allSimulators = try SimulatorManager.listAvailableSimulators().unwrap()

          // If an iOS simulator is booted, use that
          if allSimulators.contains(where: { $0.state == .booted }) {
            return device("booted")
          } else {
            // swiftlint:disable:next line_length
            log.error(
              "To run on a simulator, you must either use the '--simulator' option or have a valid simulator running already. To list available simulators, use the following command:"
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
