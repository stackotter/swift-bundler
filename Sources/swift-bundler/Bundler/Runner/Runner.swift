import Foundation

#if canImport(AppKit)
  import AppKit
#endif

/// A utility for running apps.
enum Runner {
  /// Runs the given app.
  /// - Parameters:
  ///   - bundlerOutput: The output of the bundler.
  ///   - bundleIdentifier: The app's bundle identifier.
  ///   - device: The device to run the app on.
  ///   - arguments: Command line arguments to pass to the app.
  ///   - environmentVariables: Environment variables to pass to the app.
  /// - Returns: Returns a failure if the app fails to run.
  static func run(
    bundlerOutput: BundlerOutputStructure,
    bundleIdentifier: String,
    device: Device,
    arguments: [String] = [],
    environmentVariables: [String: String]
  ) -> Result<Void, RunnerError> {
    // TODO: Test `arguments` on an actual iOS when I get the chance
    log.info("Running '\(bundlerOutput.bundle.lastPathComponent)'")

    switch device {
      case .macOS:
        guard let bundlerOutput = RunnableBundlerOutputStructure(bundlerOutput) else {
          return .failure(.missingExecutable(device, bundlerOutput))
        }
        return runMacOSApp(
          bundlerOutput: bundlerOutput,
          arguments: arguments,
          environmentVariables: environmentVariables
        )
      case .linux:
        print(bundlerOutput)
        guard let bundlerOutput = RunnableBundlerOutputStructure(bundlerOutput) else {
          return .failure(.missingExecutable(device, bundlerOutput))
        }
        return runLinuxExecutable(
          bundlerOutput: bundlerOutput,
          arguments: arguments,
          environmentVariables: environmentVariables
        )
      case .iOS:
        return runIOSApp(
          bundlerOutput: bundlerOutput,
          arguments: arguments,
          environmentVariables: environmentVariables
        )
      case .visionOS:
        return runVisionOSApp(
          bundlerOutput: bundlerOutput,
          arguments: arguments,
          environmentVariables: environmentVariables
        )
      case .tvOS:
        return runTVOSApp(
          bundlerOutput: bundlerOutput,
          arguments: arguments,
          environmentVariables: environmentVariables
        )
      case .iOSSimulator(let id), .visionOSSimulator(let id), .tvOSSimulator(let id):
        return runSimulatorApp(
          bundlerOutput: bundlerOutput,
          bundleIdentifier: bundleIdentifier,
          simulatorId: id,
          arguments: arguments,
          environmentVariables: environmentVariables
        )
    }
  }

  /// Loads a set of environment variables from an environment file.
  /// - Parameter environmentFile: A file containing lines of the form 'key=value'.
  /// - Returns: A dictionary containing the environment variables, or a failure if an error occurs.
  static func loadEnvironmentVariables(
    from environmentFile: URL
  ) -> Result<[String: String], RunnerError> {
    let contents: String
    do {
      contents = try String(contentsOf: environmentFile)
    } catch {
      return .failure(.failedToReadEnvironmentFile(environmentFile, error))
    }

    let lines = contents.split(separator: "\n", omittingEmptySubsequences: true)
    var variables: [String: String] = [:]
    for line in lines {
      let parts = line.split(separator: "=", maxSplits: 1)
      guard let key = parts.first, let value = parts.last else {
        return .failure(.failedToParseEnvironmentFileEntry(line: String(line)))
      }
      variables[String(key)] = String(value)
    }

    return .success(variables)
  }

  /// Runs an app on the current macOS device.
  /// - Parameters:
  ///   - bundlerOutput: The output of the bundler.
  ///   - arguments: Command line arguments to pass to the app.
  ///   - environmentVariables: Environment variables to pass to the app.
  /// - Returns: A failure if an error occurs.
  static func runMacOSApp(
    bundlerOutput: RunnableBundlerOutputStructure,
    arguments: [String],
    environmentVariables: [String: String]
  ) -> Result<Void, RunnerError> {
    let executable = bundlerOutput.executable

    let process = Process.create(
      executable.path,
      runSilentlyWhenNotVerbose: false
    )
    process.arguments = arguments
    process.addEnvironmentVariables(environmentVariables)

    #if canImport(AppKit)
      // Bring the app to the foreground once launched.
      let center = NSWorkspace.shared.notificationCenter
      center.addObserver(
        forName: NSWorkspace.didLaunchApplicationNotification,
        object: nil,
        queue: OperationQueue.main
      ) { (notification: Notification) in
        guard
          let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
            as? NSRunningApplication,
          app.bundleURL == bundlerOutput.bundle
        else {
          return
        }

        app.activate()
      }
    #endif

    do {
      try process.run()
    } catch {
      return .failure(.failedToRunExecutable(.failedToRunProcess(error)))
    }

    process.waitUntilExit()

    let exitStatus = Int(process.terminationStatus)
    if exitStatus != 0 {
      return .failure(.failedToRunExecutable(.nonZeroExitStatus(exitStatus)))
    } else {
      return .success()
    }
  }

  /// Runs an app on the first connected iOS device.
  /// - Parameters:
  ///   - bundlerOutput: The output of the bundler.
  ///   - arguments: Command line arguments to pass to the app.
  ///   - environmentVariables: Environment variables to pass to the app.
  /// - Returns: A failure if an error occurs.
  static func runIOSApp(
    bundlerOutput: BundlerOutputStructure,
    arguments: [String],
    environmentVariables: [String: String]
  ) -> Result<Void, RunnerError> {
    // `ios-deploy` is explicitly resolved (instead of allowing `Process.create`
    // to handle running programs located on the user's PATH) so that a detailed
    // error message can be emitted for this easy misconfiguration issue.
    return Process.locate("ios-deploy").mapError { error in
      return .failedToLocateIOSDeploy(error)
    }.flatMap { iosDeployExecutable in
      let environmentArguments: [String]
      if !environmentVariables.isEmpty {
        // TODO: correctly escape keys and values
        let value = environmentVariables.map { key, value in
          return "\(key)=\(value)"
        }.joined(separator: " ")
        environmentArguments = ["--envs", "\(value)"]
      } else {
        environmentArguments = []
      }

      return Process.create(
        iosDeployExecutable,
        arguments: [
          "--noninteractive",
          "--bundle", bundlerOutput.bundle.path,
        ] + environmentArguments
          + arguments.flatMap { argument in
            return ["--args", argument]
          },
        runSilentlyWhenNotVerbose: false
      ).runAndWait().mapError { error in
        return .failedToRunIOSDeploy(error)
      }
    }
  }

  /// Runs an app on the first connected visionOS device.
  /// - Parameters:
  ///   - bundlerOutput: The output of the bundler.
  ///   - arguments: Command line arguments to pass to the app.
  ///   - environmentVariables: Environment variables to pass to the app.
  /// - Returns: A failure if an error occurs.
  static func runVisionOSApp(
    bundlerOutput: BundlerOutputStructure,
    arguments: [String],
    environmentVariables: [String: String]
  ) -> Result<Void, RunnerError> {
    // TODO: Implement deploying to physical visionOS devices.
    fatalError(
      "Running on visionOS devices not supported. Please open an issue if you'd like to be a tester, "
        + "none of us have any visionOS devices, hence why we haven't been able to implement or test running "
        + "Swift Bundler apps on visionOS."
    )
  }

  /// Runs an app on the first connected tvOS device.
  /// - Parameters:
  ///   - bundlerOutput: The output of the bundler.
  ///   - arguments: Command line arguments to pass to the app.
  ///   - environmentVariables: Environment variables to pass to the app.
  /// - Returns: A failure if an error occurs.
  static func runTVOSApp(
    bundlerOutput: BundlerOutputStructure,
    arguments: [String],
    environmentVariables: [String: String]
  ) -> Result<Void, RunnerError> {
    // TODO: Implement deploying to physical tvOS devices.
    fatalError("Running on tvOS devices is not yet supported.")
  }

  /// Runs an app on an Apple device simulator.
  /// - Parameters:
  ///   - bundlerOutput: The output of the bundler.
  ///   - bundleIdentifier: The app's identifier.
  ///   - simulatorId: The id of the simulator to run.
  ///   - arguments: Command line arguments to pass to the app.
  ///   - environmentVariables: Environment variables to pass to the app.
  /// - Returns: A failure if an error occurs.
  static func runSimulatorApp(
    bundlerOutput: BundlerOutputStructure,
    bundleIdentifier: String,
    simulatorId: String,
    arguments: [String],
    environmentVariables: [String: String]
  ) -> Result<Void, RunnerError> {
    log.info("Preparing simulator")
    return SimulatorManager.bootSimulator(id: simulatorId).flatMap { _ in
      log.info("Installing app")
      return SimulatorManager.installApp(bundlerOutput.bundle, simulatorId: simulatorId)
    }.flatMap { (_: Void) -> Result<Void, SimulatorManagerError> in
      log.info("Opening Simulator")
      return SimulatorManager.openSimulatorApp()
    }.flatMap { (_: Void) -> Result<Void, SimulatorManagerError> in
      log.info("Launching \(bundleIdentifier)")
      return SimulatorManager.launchApp(
        bundleIdentifier,
        simulatorId: simulatorId,
        connectConsole: true,
        arguments: arguments,
        environmentVariables: environmentVariables
      )
    }.mapError { error in
      return .failedToRunOnSimulator(error)
    }
  }

  /// Runs a linux executable.
  /// - Parameters:
  ///   - bundlerOutput: The output of the bundler.
  ///   - arguments: Command line arguments to pass to the app.
  ///   - environmentVariables: Environment variables to pass to the app.
  /// - Returns: A failure if an error occurs.
  static func runLinuxExecutable(
    bundlerOutput: RunnableBundlerOutputStructure,
    arguments: [String],
    environmentVariables: [String: String]
  ) -> Result<Void, RunnerError> {
    Process.runAppImage(bundlerOutput.executable.path, arguments: arguments)
      .mapError { error in
        .failedToRunExecutable(error)
      }
  }
}
