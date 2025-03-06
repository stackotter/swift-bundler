import Foundation

#if os(Linux)
  import Glibc
  import ProcessSpawnSync
  typealias Process = PSProcess
#endif

/// All processes that have been created using `Process.create(_:arguments:directory:pipe:)`.
///
/// If the program is killed, all processes in this array are terminated before the program exits.
var processes: [Process] = []

#if os(Linux)
  /// The PIDs of all AppImage processes started manually (due to the weird
  /// workaround required).
  var appImagePIDs: [pid_t] = []
#endif

extension Process {
  /// A string created by concatenating all of the program's arguments together. Suitable for error messages,
  /// but not necessarily 100% correct.
  private var argumentsString: String {
    // TODO: This is pretty janky (i.e. what if an arg contains spaces)
    return arguments?.joined(separator: " ") ?? ""
  }

  /// A string representation of the command, suitable only for logging (not running).
  /// Doesn't guarantee that the produced representation is faithful, but does strive
  /// to improve in that respect over time.
  var commandStringForLogging: String {
    "\(executableURL?.path ?? "<unknown>") \(argumentsString)"
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
    excludeStdError: Bool = false
  ) async -> Result<Data, ProcessError> {
    let pipe = Pipe()
    setOutputPipe(pipe, excludeStdError: excludeStdError)

    // Thanks Martin! https://forums.swift.org/t/the-problem-with-a-frozen-process-in-swift-process-class/39579/6

    let dataStream = AsyncStream.makeStream(of: Data.self)

    let handleDataTask = Task<Data, Never> {
      var output = Data()

      for await data in dataStream.stream {
        output.append(contentsOf: data)
      }

      if #available(macOS 10.15.4, *) {
        if let data = try? pipe.fileHandleForReading.readToEnd() {
          output.append(contentsOf: data)
        }
      }

      return output
    }

    pipe.fileHandleForReading.readabilityHandler = {
      dataStream.continuation.yield($0.availableData)
    }

    return await runAndWait()
      .map { _ in
        try? pipe.fileHandleForWriting.close()
        pipe.fileHandleForReading.readabilityHandler = nil

        dataStream.continuation.finish()

        return await handleDataTask.value
      }
      .mapErrorAsync { error in
        switch error {
          case .nonZeroExitStatus(let status):
            return .nonZeroExitStatusWithOutput(await handleDataTask.value, status)
          default:
            return error
        }
      }
  }

  /// Gets the process's stdout and stderr as a string.
  /// - Parameter excludeStdError: If `true`, only stdout is returned.
  /// - Returns: The process's stdout and stderr. If an error occurs, a failure is returned.
  func getOutput(excludeStdError: Bool = false) async -> Result<String, ProcessError> {
    return await getOutputData(excludeStdError: excludeStdError)
      .andThen { data in
        String(data: data, encoding: .utf8)
          .okOr(.invalidUTF8Output(output: data))
      }
  }

  /// Runs the process and waits for it to complete.
  /// - Returns: Returns a failure if the process has a non-zero exit status of fails to run.
  func runAndWait() async -> Result<Void, ProcessError> {
    log.debug(
      "Running command: '\(executableURL?.path ?? "")' with arguments: \(arguments ?? []), working directory: \(currentDirectoryURL?.path ?? FileManager.default.currentDirectoryPath)"
    )

    return await Result {
      try await withCheckedThrowingContinuation {
        (continuation: CheckedContinuation<Void, Error>) in
        terminationHandler = { process in
          continuation.resume()
        }

        do {
          try run()
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }.mapError(ProcessError.failedToRunProcess)
      .andThen { _ in
        let exitStatus = Int(terminationStatus)
        guard exitStatus == 0 else {
          return .failure(.nonZeroExitStatus(exitStatus))
        }

        return .success()
      }
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
  ///   - directory: The directory to run the command in. Defaults to the current
  ///     directory.
  ///   - pipe: The pipe for the process's stdout and stderr. Defaults to `nil`.
  ///   - runSilentlyWhenNotVerbose: If `true`, output is captured even when no
  ///     pipe is provided id Swift Bundler wasn't run with `-v`. Defaults to
  ///     `true`.
  /// - Returns: The new process.
  static func create(
    _ tool: String,
    arguments: [String] = [],
    environment: [String: String] = [:],
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
      switch HostPlatform.hostPlatform {
        case .linux, .macOS:
          process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
          process.arguments = [tool] + arguments
        case .windows:
          process.executableURL = URL(fileURLWithPath: "C:\\Windows\\System32\\cmd.exe")
          process.arguments = ["/c", tool] + arguments
      }
    }

    var env = ProcessInfo.processInfo.environment
    if env.keys.contains("OS_ACTIVITY_DT_MODE") {
      // Fix an issue to do with Xcode breaking SwiftPackageManager
      // (https://stackoverflow.com/a/67613515)
      env["OS_ACTIVITY_DT_MODE"] = nil
    }
    for (key, value) in environment {
      env[key] = value
    }
    process.environment = env

    processes.append(process)

    return process
  }

  /// Gets the full path to the specified tool (using the `which` shell command). If
  /// you don't need to explicitly know the path from Swift, just pass the name of the
  /// tool to `Process.create` instead (which will detect that it's not a path and instead
  /// run the tool through `/usr/bin/env` which will find the tool on the user's `PATH`).
  /// - Parameter tool: The tool to expand into a full path.
  /// - Returns: The absolute path to the tool, or a failure if the tool can't be located.
  static func locate(_ tool: String) async -> Result<String, ProcessError> {
    // Restrict the set of inputs to avoid command injection. This is very dodgy but there
    // doesn't seem to be any nice way to call bash built-ins directly with an argument
    // vector. Better approaches are extremely welcome!!
    guard
      tool.allSatisfy({ character in
        character.isASCII
          && (character.isLetter
            || character.isNumber || character == "-" || character == "_")
      })
    else {
      return .failure(.invalidToolName(tool))
    }

    return await Process.create(
      "/bin/sh",
      arguments: [
        "-c",
        "which \(tool)",
      ],
      runSilentlyWhenNotVerbose: false
    )
    .getOutput()
    .map { path in
      path.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    .mapError { error in
      .failedToLocateTool(tool, error)
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
  static func runAppImage(
    _ appImage: String,
    arguments: [String],
    additionalEnvironmentVariables: [String: String] = [:]
  ) async -> Result<Void, ProcessError> {
    #if os(Linux)
      var environment = ProcessInfo.processInfo.environment
      for (key, value) in additionalEnvironmentVariables {
        guard isValidEnvironmentVariableKey(key) else {
          return .failure(.invalidEnvironmentVariableKey(key))
        }
        environment[key] = value
      }

      let environmentArray =
        environment.map { key, value in
          strdup("\(key)=\(value)")
        } + [UnsafeMutablePointer<CChar>(bitPattern: 0)]

      // Locate the tool or interpret it as a relative/absolute path.
      let executablePath: String
      switch await locate(appImage) {
        case .success(let path):
          executablePath = path
        case .failure(.invalidToolName):
          executablePath = appImage
        case .failure(let error):
          return .failure(error)
      }

      let cArguments =
        ([executablePath] + arguments).map { strdup($0) }
        + [UnsafeMutablePointer<CChar>(bitPattern: 0)]

      let selfPID = getpid()
      setpgid(0, selfPID)
      let childPID = fork()
      if childPID == 0 {
        setpgid(0, selfPID)
        execve(executablePath, cArguments, environmentArray)
        // We only ever get here if the execv fails
        Foundation.exit(-1)
      } else {
        appImagePIDs.append(childPID)
        var status: Int32 = 0
        waitpid(childPID, &status, 0)
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

      return await process.runAndWait()
        .mapError { error in
          .failedToRunProcess(error)
        }
    #endif
  }

  /// Validates an environment variable key. Currently only used by a Linux workaround
  /// that has to interface with low-level APIs.
  private static func isValidEnvironmentVariableKey(_ key: String) -> Bool {
    key.allSatisfy({ character in
      character.isASCII
        && (character.isLetter || character.isNumber || character == "_")
    }) && key.first?.isNumber == false
  }
}
