import Foundation

#if canImport(Darwin)
  import Darwin
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
      case .iOSSimulator(let id):
        return runIOSSimulatorApp(
          bundle: bundle,
          bundleIdentifier: bundleIdentifier,
          simulatorId: id,
          arguments: arguments,
          environmentVariables: environmentVariables
        )
      case .visionOS:
        return runVisionOSApp(
          bundle: bundle,
          arguments: arguments,
          environmentVariables: environmentVariables
        )
      case .visionOSSimulator(let id):
        return runVisionOSSimulatorApp(
          bundle: bundle,
          bundleIdentifier: bundleIdentifier,
          simulatorId: id,
          arguments: arguments,
          environmentVariables: environmentVariables
        )
      case .linux:
        // TODO: Implement linux app running
        fatalError("TODO: Implement linux app running")
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
    #if canImport(Darwin)
      let tmp = FileManager.default.temporaryDirectory
      let uuid = UUID().uuidString
      let stdinPipe = tmp.appendingPathComponent("stdin_\(uuid)")
      let stdoutPipe = tmp.appendingPathComponent("stdout_\(uuid)")
      let stderrPipe = tmp.appendingPathComponent("stderr_\(uuid)")

      guard
        mkfifo(stdinPipe.path, 0o777) == 0,
        mkfifo(stdoutPipe.path, 0o777) == 0,
        mkfifo(stderrPipe.path, 0o777) == 0
      else {
        return .failure(.failedToCreateNamedPipes(errno: Int(errno)))
      }

      let process = Process.create(
        "open",
        arguments: [
          "-a", bundle.path,
          "-W",
          "--stdin", stdinPipe.path,
          "--stdout", stdoutPipe.path,
          "--stderr", stderrPipe.path,
          "--args",
        ] + arguments,
        runSilentlyWhenNotVerbose: false
      )
      process.addEnvironmentVariables(environmentVariables)

      do {
        try process.run()
      } catch {
        return .failure(.failedToRunExecutable(.failedToRunProcess(error)))
      }

      let stdinFlags = fcntl(STDIN_FILENO, F_GETFL, 0)
      guard fcntl(STDIN_FILENO, F_SETFL, stdinFlags | O_NONBLOCK) != -1 else {
        return .failure(.failedToMakeStdinNonBlocking(errno: Int(errno)))
      }
      let appStdin = open(stdinPipe.path, O_WRONLY)
      let appStdout = open(stdoutPipe.path, O_RDONLY | O_NONBLOCK)
      let appStderr = open(stderrPipe.path, O_RDONLY | O_NONBLOCK)
      let events = Int16(POLLIN | POLLHUP)
      var readFDs = [
        pollfd(fd: appStdout, events: events, revents: 0),
        pollfd(fd: appStderr, events: events, revents: 0),
        pollfd(fd: STDIN_FILENO, events: events, revents: 0),
      ]

      var buffer: [UInt8] = Array(repeating: 0, count: 1024)
      while process.isRunning {
        _ = poll(&readFDs, nfds_t(readFDs.count), 0)

        let stdinCount = read(STDIN_FILENO, &buffer, buffer.count)
        if stdinCount > 0 {
          print("success")
          write(appStdin, &buffer, stdinCount)
        }

        let appStdoutCount = read(appStdout, &buffer, buffer.count)
        if appStdoutCount > 0 {
          print("success")
          write(STDOUT_FILENO, &buffer, appStdoutCount)
        }

        let appStderrCount = read(appStderr, &buffer, buffer.count)
        if appStderrCount > 0 {
          print("success")
          write(STDERR_FILENO, &buffer, appStderrCount)
        }
      }

      let exitStatus = Int(process.terminationStatus)
      if exitStatus != 0 {
        return .failure(.failedToRunExecutable(.nonZeroExitStatus(exitStatus)))
      } else {
        return .success()
      }
    #else
      return .failure(.cannotRunMacOSAppWithoutDarwin)
    #endif
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

  /// Runs an app on an iOS simulator.
  /// - Parameters:
  ///   - bundle: The app bundle to run.
  ///   - bundleIdentifier: The app's identifier.
  ///   - simulatorId: The id of the simulator to run.
  ///   - arguments: Command line arguments to pass to the app.
  ///   - environmentVariables: Environment variables to pass to the app.
  /// - Returns: A failure if an error occurs.
  static func runIOSSimulatorApp(
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
      return .failedToRunOnIOSSimulator(error)
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
    // `ios-deploy` is explicitly resolved (instead of allowing `Process.create`
    // to handle running programs located on the user's PATH) so that a detailed
    // error message can be emitted for this easy misconfiguration issue.
    return Process.locate("ios-deploy").mapError { error in
      .failedToLocateIOSDeploy(error)
    }.flatMap { xrosDeployExecutable in
      let environmentArguments: [String]
      if !environmentVariables.isEmpty {
        // TODO: correctly escape keys and values
        let value = environmentVariables.map { key, value in
          "\(key)=\(value)"
        }.joined(separator: " ")
        environmentArguments = ["--envs", "\(value)"]
      } else {
        environmentArguments = []
      }

      return Process.create(
        xrosDeployExecutable,
        arguments: [
          "--noninteractive",
          "--bundle", bundle.path,
        ] + environmentArguments
          + arguments.flatMap { argument in
            ["--args", argument]
          },
        runSilentlyWhenNotVerbose: false
      ).runAndWait().mapError { error in
        .failedToRunIOSDeploy(error)
      }
    }
  }

  /// Runs an app on an visionOS simulator.
  /// - Parameters:
  ///   - bundle: The app bundle to run.
  ///   - bundleIdentifier: The app's identifier.
  ///   - simulatorId: The id of the simulator to run.
  ///   - arguments: Command line arguments to pass to the app.
  ///   - environmentVariables: Environment variables to pass to the app.
  /// - Returns: A failure if an error occurs.
  static func runVisionOSSimulatorApp(
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
      .failedToRunOnVisionOSSimulator(error)
    }
  }
}
