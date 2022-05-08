import Foundation

/// All processes that have been created using `Process.create(_:arguments:directory:pipe:)`.
///
/// If the program is killed, all processes in this array are terminated before the program exits.
var processes: [Process] = []

extension Process {
  /// Sets the pipe for the process's stdout and stderr.
  /// - Parameter excludeStdError: If `true`, only stdout is piped.
  /// - Parameter pipe: The pipe.
  func setOutputPipe(_ pipe: Pipe, excludeStdError: Bool = false) {
    standardOutput = pipe
    if !excludeStdError {
      standardError = pipe
    }
  }

  /// Gets the process's stdout and stderr as `Data`.
  /// - Parameter excludeStdError: If `true`, only stdout is returned.
  /// - Returns: The process's stdout and stderr. If an error occurs, a failure is returned.
  func getOutputData(excludeStdError: Bool = false) -> Result<Data, ProcessError> {
    let pipe = Pipe()
    setOutputPipe(pipe, excludeStdError: excludeStdError)

    return runAndWait()
      .map { _ in
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return data
      }
  }

  /// Gets the process's stdout and stderr as a string.
  /// - Parameter excludeStdError: If `true`, only stdout is returned.
  /// - Returns: The process's stdout and stderr. If an error occurs, a failure is returned.
  func getOutput(excludeStdError: Bool = false) -> Result<String, ProcessError> {
    return getOutputData(excludeStdError: excludeStdError)
      .flatMap { data in
        guard let output = String(data: data, encoding: .utf8) else {
          return .failure(.invalidUTF8Output(output: data))
        }

        return .success(output)
      }
  }

  /// Runs the process and waits for it to complete.
  /// - Returns: Returns a failure if the process has a non-zero exit status of fails to run.
  func runAndWait() -> Result<Void, ProcessError> {
    do {
      try run()
    } catch {
      return .failure(.failedToRunProcess(error))
    }

    waitUntilExit()

    let exitStatus = Int(terminationStatus)
    if exitStatus != 0 {
      return .failure(.nonZeroExitStatus(exitStatus))
    }

    return .success()
  }

  /// Creates a new process (but doesn't run it).
  /// - Parameters:
  ///   - tool: The tool.
  ///   - arguments: The tool's arguments.
  ///   - directory: The directory to run the command in. Defaults to the current directory.
  ///   - pipe: The pipe for the process's stdout and stderr. Defaults to `nil`.
  /// - Returns: The new process.
  static func create(_ tool: String, arguments: [String] = [], directory: URL? = nil, pipe: Pipe? = nil) -> Process {
    let process = Process()

    if let pipe = pipe {
      process.setOutputPipe(pipe)
    }

    process.currentDirectoryURL = directory?.standardizedFileURL.absoluteURL
    process.launchPath = tool
    process.arguments = arguments

    // Fix an issue to do with Xcode breaking SwiftPackageManager (https://stackoverflow.com/a/67613515)
    if ProcessInfo.processInfo.environment.keys.contains("OS_ACTIVITY_DT_MODE") {
      var env = ProcessInfo.processInfo.environment
      env["OS_ACTIVITY_DT_MODE"] = nil
      process.environment = env
    }

    processes.append(process)

    return process
  }

  /// Gets the full path to the specified tool (using the `which` shell command).
  /// - Parameter tool: The tool to expand into a full path.
  /// - Returns: The absolute path to the tool, or a failure if the tool can't be located.
  static func locate(_ tool: String) -> Result<String, ProcessError> {
    Process.create(
      "/bin/zsh",
      arguments: [
        "-c",
        "which \(tool)"
      ]
    ).getOutput().map { path in
      return path.trimmingCharacters(in: .whitespacesAndNewlines)
    }
  }
}
