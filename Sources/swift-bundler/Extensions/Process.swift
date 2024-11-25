import Foundation

#if os(Linux)
  import Glibc
#endif

/// All processes that have been created using `Process.create(_:arguments:directory:pipe:)`.
///
/// If the program is killed, all processes in this array are terminated before the program exits.
var processes: [Process] = []

extension Process {
  /// A string created by concatenating all of the program's arguments together. Suitable for error messages,
  /// but not necessarily 100% correct.
  var argumentsString: String {
    // TODO: This could instead be `commandString` and we infer the human friendly name from the executableURL
    //   (remembering that if the url is `/usr/bin/env`, the path we care about is actually the first argument)
    // TODO: This is pretty janky (i.e. what if an arg contains spaces)
    return arguments?.joined(separator: " ") ?? ""
  }

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
  /// - Parameters:
  ///   - excludeStdError: If `true`, only stdout is returned.
  ///   - handleLine: A handler to run every time that a line is received.
  /// - Returns: The process's stdout and stderr. If an error occurs, a failure is returned.
  func getOutputData(
    excludeStdError: Bool = false,
    handleLine: ((String) -> Void)? = nil
  ) -> Result<Data, ProcessError> {
    let pipe = Pipe()
    setOutputPipe(pipe, excludeStdError: excludeStdError)

    // Thanks Martin! https://forums.swift.org/t/the-problem-with-a-frozen-process-in-swift-process-class/39579/6
    var output = Data()
    var currentLine: String?
    let group = DispatchGroup()
    group.enter()
    pipe.fileHandleForReading.readabilityHandler = { fh in
      // TODO: All of this Process code is getting pretty ridiculous and janky, we should switch to
      //   the experimental proposed Subprocess API (swift-experimental-subprocess)
      let newData = fh.availableData
      if newData.isEmpty {
        pipe.fileHandleForReading.readabilityHandler = nil
        group.leave()
      } else {
        output.append(contentsOf: newData)
        if let handleLine = handleLine, let string = String(data: newData, encoding: .utf8) {
          let lines = ((currentLine ?? "") + string).split(
            separator: "\n", omittingEmptySubsequences: false)
          if let lastLine = lines.last, lastLine != "" {
            currentLine = String(lastLine)
          } else {
            currentLine = nil
          }

          for line in lines.dropLast() {
            handleLine(String(line))
          }
        }
      }
    }

    return runAndWait()
      .map { _ in
        group.wait()
        if let currentLine = currentLine {
          handleLine?(currentLine)
        }
        return output
      }
      .mapError { error in
        switch error {
          case .nonZeroExitStatus(let status):
            return .nonZeroExitStatusWithOutput(output, status)
          default:
            return error
        }
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
    log.debug("Running command: '\(executableURL?.path ?? "")' with arguments: \(arguments ?? [])")

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

  /// Adds environment variables to the process's environment.
  /// - Parameter variables: The key value pairs to add.
  func addEnvironmentVariables(_ variables: [String: String]) {
    var environment = environment ?? ProcessInfo.processInfo.environment
    for (key, value) in variables {
      environment[key] = value
    }
    self.environment = environment
  }

  /// Creates a new process (but doesn't run it).
  /// - Parameters:
  ///   - tool: The tool.
  ///   - arguments: The tool's arguments.
  ///   - directory: The directory to run the command in. Defaults to the current directory.
  ///   - pipe: The pipe for the process's stdout and stderr. Defaults to `nil`.
  ///   - runSilentlyWhenNotVerbose: If `true`, output is captured even when no pipe is provided id Swift Bundler wasn't run with `-v`.
  ///                                Defaults to `true`.
  /// - Returns: The new process.
  static func create(
    _ tool: String,
    arguments: [String] = [],
    directory: URL? = nil,
    pipe: Pipe? = nil,
    runSilentlyWhenNotVerbose: Bool = true
  ) -> Process {
    let process = Process()

    if let pipe = pipe {
      process.setOutputPipe(pipe)
    } else if log.logLevel == .info && runSilentlyWhenNotVerbose {
      // Silence output by default when not verbose.
      process.setOutputPipe(Pipe())
    }

    process.currentDirectoryURL = directory?.standardizedFileURL.absoluteURL

    // If tool isn't a path, assume it's on the user's PATH
    if tool.hasPrefix("/") || tool.hasPrefix("./") {
      process.executableURL = URL(fileURLWithPath: tool)
      process.arguments = arguments
    } else {
      process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
      process.arguments = [tool] + arguments
    }

    // Fix an issue to do with Xcode breaking SwiftPackageManager (https://stackoverflow.com/a/67613515)
    if ProcessInfo.processInfo.environment.keys.contains("OS_ACTIVITY_DT_MODE") {
      var env = ProcessInfo.processInfo.environment
      env["OS_ACTIVITY_DT_MODE"] = nil
      process.environment = env
    }

    processes.append(process)

    return process
  }

  /// Gets the full path to the specified tool (using the `which` shell command). If
  /// you don't need to explicitly know the path from Swift, just pass the name of the
  /// tool to `Process.create` instead (which will detect that it's not a path and instead
  /// run the tool through `/usr/bin/env` which will find the tool on the user's `PATH`).
  /// - Parameter tool: The tool to expand into a full path.
  /// - Returns: The absolute path to the tool, or a failure if the tool can't be located.
  static func locate(_ tool: String) -> Result<String, ProcessError> {
    Process.create(
      "/bin/sh",
      arguments: [
        "-c",
        "which \(tool)",
      ]
    ).getOutput().map { path in
      return path.trimmingCharacters(in: .whitespacesAndNewlines)
    }
  }

  /// Runs an app image. For some reason ``Foundation/Process`` can't handle
  /// app images. It just keeps waiting indefinitely even once the process
  /// has clearly finished. It also can't terminate them. App images probably
  /// just do some weird forking or something, but doing the process management
  /// ourselves seems to fix the issues.
  ///
  /// The issue occurs even without any pipes attached, so it's not the classic
  /// full pipes issue.
  static func runAppImage(_ appImage: String, arguments: [String]) -> Result<Void, ProcessError> {
    #if os(Linux)
      let selfPid = getpid()
      setpgid(0, selfPid)
      let childPid = fork()
      if childPid == 0 {
        setpgid(0, selfPid)
        let cArguments =
          (["/usr/bin/env", appImage] + arguments).map { strdup($0) }
          + [UnsafeMutablePointer<CChar>(bitPattern: 0)]
        execv("/usr/bin/env", cArguments)
        // We only ever get here if the execv fails
        Foundation.exit(-1)
      } else {
        var status: Int32 = 0
        waitpid(childPid, &status, 0)
        if status != 0 {
          return .failure(
            .nonZeroExitStatus(Int(status))
          )
        } else {
          return .success()
        }
      }
    #else
      let process = Process.create(
        appImage,
        arguments: arguments,
        runSilentlyWhenNotVerbose: false
      )

      return process.runAndWait()
        .mapError { error in
          .failedToRunProcess(error)
        }
    #endif
  }
}
