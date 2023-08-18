import Foundation

/// An error returned by ``Runner``.
enum RunnerError: LocalizedError {
  case failedToRunExecutable(ProcessError)
  case failedToLocateIOSDeploy(ProcessError)
  case failedToRunIOSDeploy(ProcessError)
  case failedToLocateVisionOSDeploy(ProcessError)
  case failedToRunVisionOSDeploy(ProcessError)
  case failedToReadEnvironmentFile(URL, Error)
  case failedToParseEnvironmentFileEntry(line: String)
  case failedToRunOnIOSSimulator(SimulatorManagerError)
  case failedToRunOnVisionOSSimulator(SimulatorManagerError)

  var errorDescription: String? {
    switch self {
      case .failedToRunExecutable(let error):
        return "Failed to run executable: \(error)"
      case .failedToLocateIOSDeploy:
        return Output {
          "'ios-deploy' must be installed to run apps on iOS"
          ExampleCommand("brew install ios-deploy")
        }.body
      case .failedToRunIOSDeploy:
        return Output {
          "Failed to run 'ios-deploy'"
          "Have you trusted the provisioning profile in settings? (General > VPN & Device Management)"
        }.body
      case .failedToLocateVisionOSDeploy:
        return Output {
          "'xros-deploy' must be installed to run apps on visionOS"
          ExampleCommand("brew install xros-deploy")
        }.body
      case .failedToRunVisionOSDeploy:
        return Output {
          "Failed to run 'xros-deploy'"
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
    }
  }
}
