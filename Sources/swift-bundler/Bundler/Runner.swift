import Foundation

/// A utility for running apps.
enum Runner {
  /// Runs the given app.
  /// - Parameters:
  ///   - bundle: The app bundle to run.
  ///   - platform: The platform to run the app on. Unless it's ``Platform/iOS``, it must match the current platform.
  /// - Returns: Returns a failure if the app fails to run.
  static func run(bundle: URL, platform: Platform) -> Result<Void, RunnerError> {
    log.info("Running '\(bundle.lastPathComponent)'")
    switch platform {
      case .macOS:
        return runMacOSApp(bundle: bundle)
      case .iOS:
        return runIOSApp(bundle: bundle)
    }
  }

  static func runMacOSApp(bundle: URL) -> Result<Void, RunnerError> {
    let appName = bundle.deletingPathExtension().lastPathComponent
    let executable = bundle.appendingPathComponent("Contents/MacOS/\(appName)")
    let process = Process.create(executable.path)
    return process.runAndWait()
      .mapError { error in
        .failedToRunExecutable(error)
      }
  }

  static func runIOSApp(bundle: URL) -> Result<Void, RunnerError> {
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
