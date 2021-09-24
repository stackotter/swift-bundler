import Foundation

enum Shell {
  static var tasks: [Process] = []

  static func terminateTasks() {
    for task in tasks {
      task.terminate()
    }
  }

  static func runSilently(_ command: String, _ dir: URL? = nil) {
    let pipe = Pipe()
    let task = createProcess(command, dir, pipe)
    task.launch()
    task.waitUntilExit()
    return
  }

  static func getOutput(_ command: String, _ dir: URL? = nil) -> String {
    let pipe = Pipe()
    let task = createProcess(command, dir, pipe)
    task.launch()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    guard let output = String(data: data, encoding: .utf8) else {
      terminate("Failed to get output of shell command `\(command)`")
    }
    return output
  }

  static func getExitStatus(_ command: String, _ dir: URL? = nil, silent: Bool = false) -> Int {
    let pipe = silent ? Pipe() : nil
    let task = createProcess(command, dir, pipe)
    task.launch()
    task.waitUntilExit()
    return Int(task.terminationStatus)
  }

  private static func createProcess(_ command: String, _ dir: URL?, _ pipe: Pipe?) -> Process {
    let task = Process()
    if let pipe = pipe {
      task.standardOutput = pipe
      task.standardError = pipe
    }

    if let dir = dir {
      task.arguments = ["-c", "cd \(dir.path); \(command)"]
    } else {
      task.arguments = ["-c", "\(command)"]
    }
    task.launchPath = "/bin/zsh"
    tasks.append(task)

    return task
  }
}