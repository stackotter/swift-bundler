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
  ) async -> Result<Void, RunnerError> {
    // TODO: Test `arguments` on an actual iOS when I get the chance
    log.info("Running '\(bundlerOutput.bundle.lastPathComponent)'")

    switch device {
      case .host(let platform):
        guard let bundlerOutput = RunnableBundlerOutputStructure(bundlerOutput) else {
          return .failure(.missingExecutable(device, bundlerOutput))
        }

        switch platform {
          case .macOS:
            return await runMacOSAppOnHost(
              bundlerOutput: bundlerOutput,
              arguments: arguments,
              environmentVariables: environmentVariables
            )
          case .linux:
            return await runLinuxAppOnHost(
              bundlerOutput: bundlerOutput,
              arguments: arguments,
              environmentVariables: environmentVariables
            )
          case .windows:
            return await runWindowsAppOnHost(
              bundlerOutput: bundlerOutput,
              arguments: arguments,
              environmentVariables: environmentVariables
            )
        }
      case .connected(let connectedDevice):
        return await runApp(
          on: connectedDevice,
          bundlerOutput: bundlerOutput,
          bundleIdentifier: bundleIdentifier,
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

  /// Runs an app on the host device. Assumes that the host is a macOS
  /// machine.
  /// - Parameters:
  ///   - bundlerOutput: The output of the bundler.
  ///   - arguments: Command line arguments to pass to the app.
  ///   - environmentVariables: Environment variables to pass to the app.
  /// - Returns: A failure if an error occurs.
  static func runMacOSAppOnHost(
    bundlerOutput: RunnableBundlerOutputStructure,
    arguments: [String],
    environmentVariables: [String: String]
  ) async -> Result<Void, RunnerError> {
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
      try await process.runAndWait().get()
    } catch {
      return .failure(.failedToRunExecutable(.failedToRunProcess(error)))
    }

    let exitStatus = Int(process.terminationStatus)
    if exitStatus != 0 {
      return .failure(.failedToRunExecutable(.nonZeroExitStatus(exitStatus)))
    } else {
      return .success()
    }
  }

  /// Runs a linux app on the host device. Assumes that the host is a Linux
  /// machine.
  /// - Parameters:
  ///   - bundlerOutput: The output of the bundler.
  ///   - arguments: Command line arguments to pass to the app.
  ///   - environmentVariables: Environment variables to pass to the app.
  /// - Returns: A failure if an error occurs.
  static func runLinuxAppOnHost(
    bundlerOutput: RunnableBundlerOutputStructure,
    arguments: [String],
    environmentVariables: [String: String]
  ) async -> Result<Void, RunnerError> {
    // runAppImage is a workaround required to run certain app images, but it
    // works for regular executable too so we just use it in all cases.
    await Process.runAppImage(bundlerOutput.executable.path, arguments: arguments)
      .mapError { error in
        .failedToRunExecutable(error)
      }
  }

  /// Runs a Windows app on the host device. Assumes that the host is a Windows
  /// machine.
  /// - Parameters:
  ///   - bundlerOutput: The output of the bundler.
  ///   - arguments: Command line arguments to pass to the app.
  ///   - environmentVariables: Environment variables to pass to the app.
  /// - Returns: A failure if an error occurs.
  static func runWindowsAppOnHost(
    bundlerOutput: RunnableBundlerOutputStructure,
    arguments: [String],
    environmentVariables: [String: String]
  ) async -> Result<Void, RunnerError> {
    await Process.create(
      bundlerOutput.executable.path,
      arguments: arguments,
      environment: environmentVariables
    ).runAndWait().mapError { error in
      .failedToRunExecutable(error)
    }
  }

  /// Runs an app on a connected device or simulator.
  /// - Parameters:
  ///   - connectedDevice: The device/simulator to run the app on.
  ///   - bundlerOutput: The output of the bundler.
  ///   - bundleIdentifier: The app's bundle identifier.
  ///   - arguments: Command line arguments to pass to the app.
  ///   - environmentVariables: Environment variables to pass to the app.
  /// - Returns: A failure if an error occurs.
  static func runApp(
    on connectedDevice: ConnectedDevice,
    bundlerOutput: BundlerOutputStructure,
    bundleIdentifier: String,
    arguments: [String],
    environmentVariables: [String: String]
  ) async -> Result<Void, RunnerError> {
    if connectedDevice.platform.isSimulator {
      return await runAppOnSimulator(
        simulatorId: connectedDevice.id,
        bundlerOutput: bundlerOutput,
        bundleIdentifier: bundleIdentifier,
        arguments: arguments,
        environmentVariables: environmentVariables
      )
    } else {
      return await runAppOnPhysicalDevice(
        deviceId: connectedDevice.id,
        bundlerOutput: bundlerOutput,
        bundleIdentifier: bundleIdentifier,
        arguments: arguments,
        environmentVariables: environmentVariables
      )
    }
  }

  static func runAppOnPhysicalDevice(
    deviceId: String,
    bundlerOutput: BundlerOutputStructure,
    bundleIdentifier: String,
    arguments: [String],
    environmentVariables: [String: String]
  ) async -> Result<Void, RunnerError> {
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

    return await Process.create("xcode-select", arguments: ["--print-path"])
      .getOutput()
      .mapError(RunnerError.failedToGetXcodeDeveloperDirectory)
      .map { output in
        let path = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return URL(fileURLWithPath: path) / "usr/bin/devicectl"
      }
      .andThen { (devicectlExecutable: URL) in
        // ios-deploy doesn't work well with newer Xcode versions because Apple
        // made a few breaking changes. Luckily, Apple created the devicectl
        // tool at around the same time. If we detect devicectl, we use it
        // because it's more likely to work, otherwise we fall back to
        // ios-deploy.

        guard devicectlExecutable.exists() else {
          // Fall back to ios-deploy.
          // `ios-deploy` is explicitly resolved so that a detailed error
          // message can be emitted for this easy misconfiguration issue.
          return await Process.locate("ios-deploy")
            .mapError(RunnerError.failedToLocateIOSDeploy)
            .andThen { iosDeployExecutable in
              await Process.create(
                iosDeployExecutable,
                arguments: [
                  "--noninteractive",
                  "--bundle", bundlerOutput.bundle.path,
                  "--id", deviceId,
                ] + environmentArguments
                  + arguments.flatMap { argument in
                    return ["--args", argument]
                  },
                runSilentlyWhenNotVerbose: false
              ).runAndWait().mapError(RunnerError.failedToRunIOSDeploy)
            }
        }

        // Install and run with devicectl
        return await Process.create(
          devicectlExecutable.path,
          arguments: [
            "device", "install", "app",
            "--device", deviceId,
            bundlerOutput.bundle.path,
          ],
          runSilentlyWhenNotVerbose: false
        ).runAndWait().andThen { _ in
          await Process.create(
            devicectlExecutable.path,
            arguments: [
              "device", "process", "launch",
              "--device", deviceId,
              "--console",
              bundleIdentifier,
            ],
            runSilentlyWhenNotVerbose: false
          ).runAndWait()
        }.mapError(RunnerError.failedToRunAppOnConnectedDevice)
      }
  }

  /// Runs an app on an Apple device simulator.
  /// - Parameters:
  ///   - simulatorId: The id of the simulator to run.
  ///   - bundlerOutput: The output of the bundler.
  ///   - bundleIdentifier: The app's identifier.
  ///   - arguments: Command line arguments to pass to the app.
  ///   - environmentVariables: Environment variables to pass to the app.
  /// - Returns: A failure if an error occurs.
  static func runAppOnSimulator(
    simulatorId: String,
    bundlerOutput: BundlerOutputStructure,
    bundleIdentifier: String,
    arguments: [String],
    environmentVariables: [String: String]
  ) async -> Result<Void, RunnerError> {
    log.info("Preparing simulator")
    return await SimulatorManager.bootSimulator(id: simulatorId).andThen { _ in
      log.info("Installing app")
      return await SimulatorManager.installApp(bundlerOutput.bundle, simulatorId: simulatorId)
    }.andThen { (_: Void) -> Result<Void, SimulatorManagerError> in
      log.info("Opening Simulator")
      return await SimulatorManager.openSimulatorApp()
    }.andThen { (_: Void) -> Result<Void, SimulatorManagerError> in
      log.info("Launching \(bundleIdentifier)")
      return await SimulatorManager.launchApp(
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
}
