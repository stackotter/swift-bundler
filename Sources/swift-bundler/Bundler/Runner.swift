import Foundation

/// A utility for running apps.
enum Runner {
  /// Runs the given app.
  /// - Parameters:
  ///   - bundle: The app bundle to run.
  ///   - platform: The platform to run the app on. Unless it's ``Platform/iOS``, it must match the current platform.
  ///   - environmentFile: A file containing environment variables to pass to the app.
  /// - Returns: Returns a failure if the app fails to run.
  static func run(
    bundle: URL,
    platform: Platform,
    environmentFile: URL?
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

    switch platform {
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

  static func runMacOSApp(
    bundle: URL,
    environmentVariables: [String: String]
  ) -> Result<Void, RunnerError> {
    let appName = bundle.deletingPathExtension().lastPathComponent
    let executable = bundle.appendingPathComponent("Contents/MacOS/\(appName)")
    let process = Process.create(executable.path, runSilentlyWhenNotVerbose: false)
    process.addEnvironmentVariables(environmentVariables)
    return process.runAndWait()
      .mapError { error in
        .failedToRunExecutable(error)
      }
  }

  static func runIOSApp(
    bundle: URL,
    environmentVariables: [String: String]
  ) -> Result<Void, RunnerError> {
    return Process.locate("ios-deploy").mapError { error in
      return .failedToLocateIOSDeploy(error)
    }.flatMap { iosDeployExecutable in
      Process.create(
        iosDeployExecutable,
        arguments: [
          "--justlaunch",
          "--bundle", bundle.path
        ],
        runSilentlyWhenNotVerbose: false
      ).runAndWait().mapError { error in
        return .failedToRunIOSDeploy(error)
      }
    }
  }
}
