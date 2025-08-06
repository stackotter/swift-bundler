import Foundation
import ErrorKit

extension Process {
  typealias Error = RichError<ErrorMessage>

  /// An error message related to Swift Bundler's `Process` extensions.
  enum ErrorMessage: Throwable {
    case invalidUTF8Output(output: Data)
    case nonZeroExitStatus(Int)
    case nonZeroExitStatusWithOutput(Data, Int)
    case failedToRunProcess
    case invalidEnvironmentVariableKey(String)
    case invalidToolName(String)
    case failedToLocateTool(String)

    var userFriendlyMessage: String {
      switch self {
        case .invalidUTF8Output:
          return "Command output was not valid utf-8 data"
        case .nonZeroExitStatus(let status):
          return "The process returned a non-zero exit status (\(status))"
        case .nonZeroExitStatusWithOutput(let data, let status):
          return
            """
            The process returned a non-zero exit status (\(status))
            \(String(data: data, encoding: .utf8) ?? "invalid utf8")
            """
        case .failedToRunProcess:
          return "The process failed to run"
        case .invalidEnvironmentVariableKey(let key):
          return "Invalid environment variable key '\(key)'"
        case .invalidToolName(let name):
          return
            """
            Invalid tool name '\(name)'. Must be contain only alphanumeric \
            characters, hyphens, and underscores.
            """
        case .failedToLocateTool(let tool):
          return "Failed to locate '\(tool)'. Ensure that you have it installed."
      }
    }
  }
}
