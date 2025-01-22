import Foundation
import StackOtterArgParser

#if SUPPORT_HOT_RELOADING
  import FileSystemWatcher
  import HotReloadingProtocol
  import Socket
#endif

/// The subcommand for running an app from a package.
struct RunCommand: ErrorHandledCommand {
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

  func wrappedRun() throws {
    guard !(skipBuild && hot) else {
      log.error("'--skip-build' is incompatible with '--hot' (nonsensical)")
      Foundation.exit(1)
    }

    guard arguments.bundler.bundler.outputIsRunnable else {
      log.error(
        """
        The chosen bundler (\(arguments.bundler.rawValue)) is bundling-only \
        (i.e. it doesn't output a runnable bundle). Choose a different bundler \
        or stick to bundling and manually install the bundle on your system to \
        run your app.
        """
      )
      Foundation.exit(1)
    }

    #if !SUPPORT_HOT_RELOADING
      if hot {
        log.error(
          """
          This build of Swift Bundler doesn't support hot reloading. Only macOS \
          and Linux builds support hot reloading.
          """
        )
        Foundation.exit(1)
      }
    #endif

    // Load configuration
    let packageDirectory = arguments.packageDirectory ?? URL.currentDirectory
    let scratchDirectory = arguments.scratchDirectory ?? packageDirectory / ".build"

    let device = try BundleCommand.resolveDevice(
      platform: arguments.platform,
      deviceSpecifier: arguments.deviceSpecifier,
      simulatorSpecifier: arguments.simulatorSpecifier
    )

    let (_, appConfiguration, _) = try BundleCommand.getConfiguration(
      arguments.appName,
      packageDirectory: packageDirectory,
      context: ConfigurationFlattener.Context(platform: device.platform),
      customFile: arguments.configurationFileOverride
    )

    let bundleCommand = BundleCommand(
      arguments: _arguments,
      skipBuild: false,
      builtWithXcode: false,
      hotReloadingEnabled: hot
    )

    // Perform bundling, or do a dry run if instructed to skip building (so
    // that we still know where the output bundle is located).
    let bundlerOutput = try bundleCommand.doBundling(
      dryRun: skipBuild,
      resolvedPlatform: device.platform,
      resolvedDevice: device
    )

    let environmentVariables =
      try environmentFile.map { file in
        try Runner.loadEnvironmentVariables(from: file).unwrap()
      } ?? [:]

    let additionalEnvironmentVariables: [String: String]
    #if SUPPORT_HOT_RELOADING
      if hot {
        var port: UInt16 = 7000

        /// Attempt to create the socket and retry with a new port if the address is
        /// already in use.
        func createSocket() async throws -> Socket {
          do {
            return try await Socket.init(
              IPv4Protocol.tcp,
              bind: IPv4SocketAddress(address: .any, port: port)
            )
          } catch Errno.addressInUse {
            port += 1
            return try await createSocket()
          }
        }

        Task {
          let socket = try await createSocket()
          try await socket.listen()

          var client = try await socket.accept()
          log.info("Received connection from runtime")

          // Just a sanity check
          try await Packet.ping.write(to: &client)
          let response = try await Packet.read(from: &client)
          guard case Packet.pong = response else {
            log.error("Expected pong, got \(response)")
            return
          }

          // TODO: Avoid loading manifest twice
          let manifest = try SwiftPackageManager.loadPackageManifest(from: packageDirectory)
            .unwrap()

          guard let platformVersion = manifest.platformVersion(for: device.platform) else {
            let manifestFile = packageDirectory.appendingPathComponent("Package.swift")
            throw CLIError.failedToGetPlatformVersion(
              platform: device.platform,
              manifest: manifestFile
            )
          }

          let architectures = bundleCommand.getArchitectures(
            platform: device.platform
          )

          try await FileSystemWatcher.watch(
            paths: [packageDirectory.appendingPathComponent("Sources").path],
            with: {
              log.info("Building 'lib\(appConfiguration.product).dylib'")
              let client = client
              Task {
                do {
                  var client = client
                  let dylibFile = try SwiftPackageManager.buildExecutableAsDylib(
                    product: appConfiguration.product,
                    buildContext: SwiftPackageManager.BuildContext(
                      packageDirectory: packageDirectory,
                      scratchDirectory: scratchDirectory,
                      configuration: arguments.buildConfiguration,
                      architectures: architectures,
                      platform: device.platform,
                      platformVersion: platformVersion,
                      additionalArguments: arguments.additionalSwiftPMArguments,
                      hotReloadingEnabled: true
                    )
                  ).unwrap()
                  log.info("Successfully built dylib")

                  try await Packet.reloadDylib(path: dylibFile).write(to: &client)
                } catch {
                  log.error("Hot reloading: \(error.localizedDescription)")
                }
              }
            },
            errorHandler: { error in
              log.error("Hot reloading: \(error.localizedDescription)")
            })
        }

        additionalEnvironmentVariables = [
          "SWIFT_BUNDLER_HOT_RELOADING": "1",
          "SWIFT_BUNDLER_SERVER": "127.0.0.1:\(port)",
        ]
      } else {
        additionalEnvironmentVariables = [:]
      }
    #else
      additionalEnvironmentVariables = [:]
    #endif

    try Runner.run(
      bundlerOutput: bundlerOutput,
      bundleIdentifier: appConfiguration.identifier,
      device: device,
      arguments: passThroughArguments,
      environmentVariables: environmentVariables.merging(
        additionalEnvironmentVariables, uniquingKeysWith: { key, _ in key }
      )
    ).unwrap()
  }
}
