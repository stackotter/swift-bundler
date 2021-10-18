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

  static func getExitStatus(
    _ command: String, 
    _ dir: URL? = nil, 
    silent: Bool = false, 
    lineHandler: ((
      _ line: String
    ) -> Void)? = nil
  ) -> Int {
    let pipe = !silent && lineHandler == nil ? nil : Pipe()
    let task = createProcess(command, dir, pipe)

    if let pipe = pipe {
      let stdOutHandle = pipe.fileHandleForReading
      DispatchQueue(label: "shell-output-reader").async {
        while true {
          let data = stdOutHandle.availableData
          if !data.isEmpty {
            if let str = String(data: data, encoding: .utf8) {
              let lines = str.split(separator: "\n")
              for line in lines {
                lineHandler?(String(line))
              }
              if !silent {
                print(str, terminator: "")
              }
            }
          } else {
            break
          }
        }
      }
    }

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
    task.launchPath = "/bin/sh"
    tasks.append(task)

    return task
  }
}