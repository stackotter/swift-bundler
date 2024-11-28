import Foundation

/// An error returned by ``Runner``.
enum RunnerError: LocalizedError {
  case failedToRunExecutable(ProcessError)
  case failedToLocateIOSDeploy(ProcessError)
  case failedToRunIOSDeploy(ProcessError)
  case failedToReadEnvironmentFile(URL, Error)
  case failedToParseEnvironmentFileEntry(line: String)
  case failedToRunOnSimulator(SimulatorManagerError)
  case missingExecutable(Device, BundlerOutputStructure)

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
      case .failedToReadEnvironmentFile(let file, _):
        return "Failed to read contents of environment file '\(file.relativePath)'"
      case .failedToParseEnvironmentFileEntry(let line):
        return "Failed to parse environment file, lines must contain '=': '\(line)'"
      case .failedToRunOnSimulator(let error):
        return "Failed to run app on simulator: \(error.localizedDescription)"
      case .missingExecutable(let device, let outputStructure):
        return """
          Failed to run '\(outputStructure.bundle.lastPathComponent)' on \
          \(device.description) because the chosen bundler didn't produce an \
          executable file. It's likely that the bundler targets a package-like \
          format instead of an executable format. Try another bundler or stick \
          to bundling.
          """
    }
  }
}
