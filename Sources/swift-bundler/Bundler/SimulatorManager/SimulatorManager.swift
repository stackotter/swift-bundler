import Foundation

/// A utility for managing simulators.
enum SimulatorManager {
  /// Lists available simulators.
  /// - Parameter searchTerm: If provided, the simulators will be filtered using
  ///   the search term.
  /// - Returns: A list of available simulators matching the search term (if
  ///   provided), or a failure if an error occurs.
  static func listAvailableSimulators(
    searchTerm: String? = nil
  ) async -> Result<[Simulator], SimulatorManagerError> {
    return await Process.create(
      "/usr/bin/xcrun",
      arguments: [
        "simctl", "list", "devices",
        searchTerm, "available", "--json",
      ].compactMap { $0 }
    ).getOutputData().mapError { error in
      .failedToRunSimCTL(error)
    }.andThen { data in
      JSONDecoder().decode(SimulatorList.self, from: data)
        .mapError(SimulatorManagerError.failedToDecodeJSON)
    }.map { simulatorList in
      simulatorList.devices
        .compactMap { (platform, platformSimulators) -> [Simulator]? in
          guard
            let os = NonMacAppleOS.allCases.first(where: { osCandidate in
              platform.hasPrefix(osCandidate.simulatorRuntimePrefix)
            })
          else {
            return nil
          }

          return platformSimulators.map { simulator in
            Simulator(
              id: simulator.id,
              name: simulator.name,
              isAvailable: simulator.isAvailable,
              isBooted: simulator.state == .booted,
              os: os
            )
          }
        }
        .flatMap { $0 }
    }
  }

  /// Boots a simulator. If it's already running, nothing is done.
  /// - Parameter id: The name or id of the simulator to start.
  /// - Returns: A failure if an error occurs.
  static func bootSimulator(id: String) async -> Result<Void, SimulatorManagerError> {
    return await Process.create(
      "/usr/bin/xcrun",
      arguments: ["simctl", "boot", id]
    )
    .getOutputData()
    .eraseSuccessValue()
    .tryRecover { error in
      // If the device is already booted, count it as a success
      guard
        case let ProcessError.nonZeroExitStatusWithOutput(data, _) = error,
        let output = String(data: data, encoding: .utf8),
        output.hasSuffix("Unable to boot device in current state: Booted\n")
      else {
        return .failure(.failedToRunSimCTL(error))
      }

      return .success()
    }
  }

  /// Launches an app on the simulator (the app must already be installed).
  /// - Parameters:
  ///   - bundleIdentifier: The app's bundle identifier.
  ///   - simulatorId: The name or id of the simulator to launch in.
  ///   - connectConsole: If `true`, the function will block and the current
  ///     process will print the stdout and stderr of the running app.
  ///   - arguments: Command line arguments to pass to the app.
  ///   - environmentVariables: Additional environment variables to pass to the
  ///     app.
  /// - Returns: A failure if an error occurs.
  static func launchApp(
    _ bundleIdentifier: String,
    simulatorId: String,
    connectConsole: Bool,
    arguments: [String],
    environmentVariables: [String: String]
  ) async -> Result<Void, SimulatorManagerError> {
    let process = Process.create(
      "/usr/bin/xcrun",
      arguments: [
        "simctl", "launch", connectConsole ? "--console-pty" : nil,
        simulatorId, bundleIdentifier,
      ].compactMap { $0 } + arguments,
      runSilentlyWhenNotVerbose: false
    )

    // TODO: Ensure that environment variables are passed correctly
    var prefixedVariables: [String: String] = [:]
    for (key, value) in environmentVariables {
      prefixedVariables["SIMCTL_CHILD_" + key] = value
    }

    process.addEnvironmentVariables(prefixedVariables)

    return await process.runAndWait().mapError { error in
      return .failedToRunSimCTL(error)
    }
  }

  /// Installs an app on the simulator.
  /// - Parameters:
  ///   - bundle: The app bundle to install.
  ///   - simulatorId: The name or id of the simulator to install on.
  /// - Returns: A failure if an error occurs.
  static func installApp(
    _ bundle: URL,
    simulatorId: String
  ) async -> Result<Void, SimulatorManagerError> {
    return await Process.create(
      "/usr/bin/xcrun",
      arguments: [
        "simctl", "install", simulatorId, bundle.path,
      ]
    ).runAndWait().mapError { error in
      return .failedToRunSimCTL(error)
    }
  }

  /// Opens the latest booted simulator in the simulator app.
  /// - Returns: A failure if an error occurs.
  static func openSimulatorApp() async -> Result<Void, SimulatorManagerError> {
    return await Process.create(
      "/usr/bin/open",
      arguments: [
        "-a", "Simulator",
      ]
    ).runAndWait().mapError { error in
      return .failedToOpenSimulator(error)
    }
  }
}
