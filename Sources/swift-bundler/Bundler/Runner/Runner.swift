import Foundation

/// A utility for running apps.
enum Runner {
  /// Runs the given app.
  /// - Parameters:
  ///   - bundle: The app bundle to run.
  ///   - bundleIdentifier: The app's bundle identifier.
  ///   - device: The device to run the app on.
  ///   - environmentFile: A file containing environment variables to pass to the app.
  /// - Returns: Returns a failure if the app fails to run.
  static func run(
    bundle: URL,
    bundleIdentifier: String,
    device: Device,
    environmentFile: URL? = nil
  ) -> Result<Void, RunnerError> {
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
          environmentVariables: environmentVariables
        )
      case .iOS:
        return runIOSApp(
          bundle: bundle,
          environmentVariables: environmentVariables
        )
      case .iOSSimulator(let id):
        return runIOSSimulatorApp(
          bundle: bundle,
          bundleIdentifier: bundleIdentifier,
          simulatorId: id,
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
  ///   - environmentVariables: Environment variables to pass to the process.
  /// - Returns: A failure if an error occurs.
  static func runMacOSApp(
    bundle: URL,
    environmentVariables: [String: String]
  ) -> Result<Void, RunnerError> {
    let appName = bundle.deletingPathExtension().lastPathComponent
    let executable = bundle.appendingPathComponent("Contents/MacOS/\(appName)")

    let process = Process.create(
      executable.path,
      runSilentlyWhenNotVerbose: false
    )
    process.addEnvironmentVariables(environmentVariables)

    return process.runAndWait().mapError { error in
      return .failedToRunExecutable(error)
    }
  }

  /// Runs an app on the first connected iOS device.
  /// - Parameters:
  ///   - bundle: The app bundle to run.
  ///   - environmentVariables: Environment variables to pass to the process.
  /// - Returns: A failure if an error occurs.
  static func runIOSApp(
    bundle: URL,
    environmentVariables: [String: String]
  ) -> Result<Void, RunnerError> {
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
          "--justlaunch",
          "--bundle", bundle.path
        ] + environmentArguments,
        runSilentlyWhenNotVerbose: false
      ).runAndWait().mapError { error in
        return .failedToRunIOSDeploy(error)
      }
    }
  }

  /// Runs an app on an iOS simulator.
  /// - Parameters:
  ///   - bundle: The app bundle to run.
  ///   - bundleIdentifier: The app's identifier.
  ///   - simulatorId: The id of the simulator to run.
  ///   - environmentVariables: Environment variables to pass to the process.
  /// - Returns: A failure if an error occurs.
  static func runIOSSimulatorApp(
    bundle: URL,
    bundleIdentifier: String,
    simulatorId: String,
    environmentVariables: [String: String]
  ) -> Result<Void, RunnerError> {
    log.info("Preparing simulator")
    return SimulatorManager.bootSimulator(id: simulatorId).flatMap { _ in
      log.info("Installing app")
      return SimulatorManager.installApp(bundle, simulatorId: simulatorId)
    }.flatMap { (_: Void) -> Result<Void, SimulatorManagerError> in
      log.info("Opening 'Simulator.app'")
      return SimulatorManager.openSimulatorApp()
    }.flatMap { (_: Void) -> Result<Void, SimulatorManagerError> in
      log.info("Launching '\(bundleIdentifier)'")
      return SimulatorManager.launchApp(
        bundleIdentifier,
        simulatorId: simulatorId,
        connectConsole: true,
        environmentVariables: environmentVariables
      )
    }.mapError { error in
      return .failedToRunOnIOSSimulator(error)
    }
  }
}
