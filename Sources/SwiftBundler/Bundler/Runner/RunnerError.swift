import Foundation
import ErrorKit

extension Runner {
  typealias Error = RichError<ErrorMessage>

  /// An error message related to ``Runner``.
  enum ErrorMessage: Throwable {
    case failedToRunExecutable
    case failedToLocateIOSDeploy
    case failedToRunIOSDeploy
    case failedToReadEnvironmentFile(URL)
    case failedToParseEnvironmentFileEntry(line: String)
    case failedToRunOnSimulator
    case missingExecutable(Device, BundlerOutputStructure)
    case failedToGetXcodeDeveloperDirectory
    case failedToRunAppOnConnectedDevice

    var userFriendlyMessage: String {
      switch self {
        case .failedToRunExecutable:
          return "Failed to run executable"
        case .failedToLocateIOSDeploy:
          return Output {
            """
            Running apps on iOS and tvOS devices requires ios-deploy or Xcode 15+ \
            (devicectl).

            """
            ExampleCommand("brew install ios-deploy")
          }.body
        case .failedToRunIOSDeploy:
          return Output {
            "Failed to run 'ios-deploy'"
            "Have you trusted the provisioning profile in settings? (General > VPN & Device Management)"
          }.body
        case .failedToReadEnvironmentFile(let file):
          return "Failed to read contents of environment file '\(file.relativePath)'"
        case .failedToParseEnvironmentFileEntry(let line):
          return "Failed to parse environment file, lines must contain '=': '\(line)'"
        case .failedToRunOnSimulator:
          return "Failed to run app on simulator"
        case .missingExecutable(let device, let outputStructure):
          return """
            Failed to run '\(outputStructure.bundle.lastPathComponent)' on \
            \(device.description) because the chosen bundler didn't produce an \
            executable file. It's likely that the bundler targets a package-like \
            format instead of an executable format. Try another bundler or stick \
            to bundling.
            """
        case .failedToGetXcodeDeveloperDirectory:
          return "Failed to get Xcode 'Developer' directory path"
        case .failedToRunAppOnConnectedDevice:
          return "Failed to run app on connected device"
      }
    }
  }
}
