import Foundation

enum ProcessError: LocalizedError {
  case invalidUTF8Output(output: Data)
  case nonZeroExitStatus(Int)
}

extension Process {
  func setOutputPipe(_ pipe: Pipe) {
    standardOutput = pipe
    standardError = pipe
  }
  
  func runSilently() {
    setOutputPipe(Pipe())
    launch()
    waitUntilExit()
  }

  func getOutput() throws -> String {
    let pipe = Pipe()
    setOutputPipe(pipe)
    
    try runAndWait()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    guard let output = String(data: data, encoding: .utf8) else {
      throw ProcessError.invalidUTF8Output(output: data)
    }
    
    return output
  }
  
  /// Runs the process and waits for it to complete.
  /// - Throws: Throws an error if the process has a non-zero exit status of fails to run.
  func runAndWait() throws {
    try run()
    waitUntilExit()
    let exitStatus = Int(terminationStatus)
    if exitStatus != 0 {
      throw ProcessError.nonZeroExitStatus(exitStatus)
    }
  }

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
