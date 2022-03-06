import Foundation

enum ProcessError: LocalizedError {
  case invalidUTF8Output(output: Data)
  case nonZeroExitStatus(Int)
  case failedToRunProcess(Error)
}

extension Process {
  /// Sets the pipe for the process's stdout and stderr.
  /// - Parameter pipe: The pipe.
  func setOutputPipe(_ pipe: Pipe) {
    standardOutput = pipe
    standardError = pipe
  }
  
  /// Gets the process's stdout and stderr as a string.
  /// - Returns: The process's stdout and stderr.
  func getOutput() -> Result<String, ProcessError> {
    let pipe = Pipe()
    setOutputPipe(pipe)
    
    return runAndWait()
      .flatMap {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        
        guard let output = String(data: data, encoding: .utf8) else {
          return .failure(.invalidUTF8Output(output: data))
        }
        
        return .success(output)
      }
  }
  
  /// Runs the process and waits for it to complete.
  /// - Throws: Throws an error if the process has a non-zero exit status of fails to run.
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

    process.currentDirectoryURL = directory
    process.launchPath = tool
    process.arguments = arguments

    return process
  }
}
