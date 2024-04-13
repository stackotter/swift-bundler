import Foundation

#if canImport(AppKit)
  import AppKit
#endif

/// A utility for running apps.
enum Runner {
  /// Runs the given app.
  /// - Parameters:
  ///   - bundle: The app bundle to run.
  ///   - bundleIdentifier: The app's bundle identifier.
  ///   - device: The device to run the app on.
  ///   - arguments: Command line arguments to pass to the app.
  ///   - environmentFile: A file containing environment variables to pass to the app.
  /// - Returns: Returns a failure if the app fails to run.
  static func run(
    bundle: URL,
    bundleIdentifier: String,
    device: Device,
    arguments: [String] = [],
    environmentFile: URL? = nil
  ) -> Result<Void, RunnerError> {
    // TODO: Test `arguments` on an actual iOS when I get the chance
    log.info("Running '\(bundle.lastPathComponent)'")
    let environmentVariables: [String: String]
    if let environmentFile = environmentFile {
      switch loadEnvironmentVariables(from: environmentFile) {
        case .success(let variables):
          environmentVariables = variables
        case .failure(let error):
          return .failure(error)
      }
    } else {
      environmentVariables = [:]
    }

    switch device {
      case .macOS:
        return runMacOSApp(
          bundle: bundle,
          arguments: arguments,
          environmentVariables: environmentVariables
        )
      case .iOS:
        return runIOSApp(
          bundle: bundle,
          arguments: arguments,
          environmentVariables: environmentVariables
        )
      case .visionOS:
        return runVisionOSApp(
          bundle: bundle,
          arguments: arguments,
          environmentVariables: environmentVariables
        )
      case .tvOS:
        return runTVOSApp(
          bundle: bundle,
          arguments: arguments,
          environmentVariables: environmentVariables
        )
      case .iOSSimulator(let id), .visionOSSimulator(let id), .tvOSSimulator(let id):
        return runSimulatorApp(
          bundle: bundle,
          bundleIdentifier: bundleIdentifier,
          simulatorId: id,
          arguments: arguments,
          environmentVariables: environmentVariables
        )
      case .linux:
        return runLinuxExecutable(
          bundle: bundle,
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
  ///   - bundle: The app bundle to run.
  ///   - arguments: Command line arguments to pass to the app.
  ///   - environmentVariables: Environment variables to pass to the app.
  /// - Returns: A failure if an error occurs.
  static func runMacOSApp(
    bundle: URL,
    arguments: [String],
    environmentVariables: [String: String]
  ) -> Result<Void, RunnerError> {
    let appName = bundle.deletingPathExtension().lastPathComponent
    let executable = bundle.appendingPathComponent("Contents/MacOS/\(appName)")

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
          app.bundleURL == bundle
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
  ///   - bundle: The app bundle to run.
  ///   - arguments: Command line arguments to pass to the app.
  ///   - environmentVariables: Environment variables to pass to the app.
  /// - Returns: A failure if an error occurs.
  static func runIOSApp(
    bundle: URL,
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
          "--bundle", bundle.path,
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
  ///   - bundle: The app bundle to run.
  ///   - arguments: Command line arguments to pass to the app.
  ///   - environmentVariables: Environment variables to pass to the app.
  /// - Returns: A failure if an error occurs.
  static func runVisionOSApp(
    bundle: URL,
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
  ///   - bundle: The app bundle to run.
  ///   - arguments: Command line arguments to pass to the app.
  ///   - environmentVariables: Environment variables to pass to the app.
  /// - Returns: A failure if an error occurs.
  static func runTVOSApp(
    bundle: URL,
    arguments: [String],
    environmentVariables: [String: String]
  ) -> Result<Void, RunnerError> {
    // TODO: Implement deploying to physical tvOS devices.
    fatalError("Running on tvOS devices is not yet supported.")
  }

  /// Runs an app on an Apple device simulator.
  /// - Parameters:
  ///   - bundle: The app bundle to run.
  ///   - bundleIdentifier: The app's identifier.
  ///   - simulatorId: The id of the simulator to run.
  ///   - arguments: Command line arguments to pass to the app.
  ///   - environmentVariables: Environment variables to pass to the app.
  /// - Returns: A failure if an error occurs.
  static func runSimulatorApp(
    bundle: URL,
    bundleIdentifier: String,
    simulatorId: String,
    arguments: [String],
    environmentVariables: [String: String]
  ) -> Result<Void, RunnerError> {
    log.info("Preparing simulator")
    return SimulatorManager.bootSimulator(id: simulatorId).flatMap { _ in
      log.info("Installing app")
      return SimulatorManager.installApp(bundle, simulatorId: simulatorId)
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

  static func runLinuxExecutable(
    bundle: URL,
    arguments: [String],
    environmentVariables: [String: String]
  ) -> Result<Void, RunnerError> {
    print("Creating")
    let process = Process.create(
      bundle.path,
      arguments: arguments,
      runSilentlyWhenNotVerbose: false
    )
    process.addEnvironmentVariables(environmentVariables)

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
}
