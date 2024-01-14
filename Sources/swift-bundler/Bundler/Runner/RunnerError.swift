import Foundation

/// An error returned by ``Runner``.
enum RunnerError: LocalizedError {
  case failedToRunExecutable(ProcessError)
  case failedToLocateIOSDeploy(ProcessError)
  case failedToRunIOSDeploy(ProcessError)
  case failedToReadEnvironmentFile(URL, Error)
  case failedToParseEnvironmentFileEntry(line: String)
  case failedToRunOnIOSSimulator(SimulatorManagerError)
  case failedToRunOnVisionOSSimulator(SimulatorManagerError)
  case cannotRunMacOSAppWithoutDarwin
  case failedToCreateNamedPipes(errno: Int)
  case failedToMakeStdinNonBlocking(errno: Int)

  var errorDescription: String? {
    switch self {
      case .failedToRunExecutable(let error):
        return "Failed to run executable: \(error)"
      case .failedToLocateIOSDeploy:
        return Output {
          "'ios-deploy' must be installed to run apps on iOS and visionOS"
          ExampleCommand("brew install ios-deploy")
        }.body
      case .failedToRunIOSDeploy:
        return Output {
          "Failed to run 'ios-deploy'"
          "Have you trusted the provisioning profile in settings? (General > VPN & Device Management)"
        }.body
      case let .failedToReadEnvironmentFile(file, _):
        return "Failed to read contents of environment file '\(file.relativePath)'"
      case let .failedToParseEnvironmentFileEntry(line):
        return "Failed to parse environment file, lines must contain '=': '\(line)'"
      case let .failedToRunOnIOSSimulator(error):
        return "Failed to run app on iOS simulator: \(error.localizedDescription)"
      case let .failedToRunOnVisionOSSimulator(error):
        return "Failed to run app on visionOS simulator: \(error.localizedDescription)"
      case .cannotRunMacOSAppWithoutDarwin:
        return
          "Cannot run a macOS app without Darwin available (this error should never occur, please open an issue on GitHub)"
      case let .failedToCreateNamedPipes(errno):
        return "Failed to create named pipes for IO redirection (errno \(errno))"
      case let .failedToMakeStdinNonBlocking(errno):
        return "Failed to make stdin non-blocking (errno \(errno))"
    }
  }
}
