import Foundation

/// An error returned by custom methods added to `Process`.
indirect enum ProcessError: LocalizedError {
  case invalidUTF8Output(output: Data)
  case nonZeroExitStatus(Int)
  case nonZeroExitStatusWithOutput(Data, Int)
  case failedToRunProcess(Error)
  case invalidEnvironmentVariableKey(String)
  case invalidToolName(String)
  case failedToLocateTool(String, ProcessError)

  var errorDescription: String? {
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
      case .failedToLocateTool(let tool, _):
        return "Failed to locate '\(tool)'. Ensure that you have it installed."
    }
  }
}
