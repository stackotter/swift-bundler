import Foundation

enum ScriptRunnerError: LocalizedError {
  case scriptDoesntExist(URL)
}

struct ScriptRunner {
  var context: Context
  
  struct Context {
    var packageDirectory: URL
  }
  
  init(_ context: Context) {
    self.context = context
  }
  
  /// Runs the prebuild script in the package of this script runner.
  /// - Throws: Throws an error if the script doesn't exist or fails to run.
  func runPrebuildScript() throws {
    let script = context.packageDirectory.appendingPathComponent("prebuild.sh")
    try runScript(script)
  }
  
  /// Runs the postbuild script in the package of this script runner.
  /// - Throws: Throws an error if the script doesn't exist or fails to run.
  func runPostbuildScript() throws {
    let script = context.packageDirectory.appendingPathComponent("postbuild.sh")
    try runScript(script)
  }
  
  /// Runs the prebuild script in the package of this script runner if it exists.
  /// - Throws: Throws an error if the script exists and fails to run.
  func runPrebuildScriptIfPresent() throws {
    do {
      try runPrebuildScript()
    } catch ScriptRunnerError.scriptDoesntExist(_) {
      return // Ignore errors if the script doesn't exist
    } catch {
      throw error
    }
  }
  
  /// Runs the postbuild script in the package of this script runner if it exists.
  /// - Throws: Throws an error if the script exists and fails to run.
  func runPostbuildScriptIfPresent() throws {
    do {
      try runPostbuildScript()
    } catch ScriptRunnerError.scriptDoesntExist(_) {
      return // Ignore errors if the script doesn't exist
    } catch {
      throw error
    }
  }
  
  /// Runs a shell script.
  /// - Parameter url: The url to the shell script.
  /// - Throws: Throws an error if the script doesn't exist or the script returns a non-zero exit status.
  func runScript(_ url: URL) throws {
    guard FileManager.default.itemExists(at: url, withType: .file) else {
      throw ScriptRunnerError.scriptDoesntExist(url)
    }
    
    let process = Process.create("/bin/sh", arguments: [url.path], directory: url.deletingLastPathComponent())
    try process.runAndWait()
  }
}
