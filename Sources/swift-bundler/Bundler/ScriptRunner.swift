import Foundation

enum ScriptRunnerError: LocalizedError {
  case scriptDoesntExist(URL)
  case failedToRunScript(ProcessError)
}

struct ScriptRunner {
  var packageDirectory: URL
  
  init(_ packageDirectory: URL) {
    self.packageDirectory = packageDirectory
  }
  
  /// Runs the prebuild script in the package of this script runner.
  func runPrebuildScript() -> Result<Void, ScriptRunnerError> {
    let script = packageDirectory.appendingPathComponent("prebuild.sh")
    return Self.runScript(script)
  }
  
  /// Runs the postbuild script in the package of this script runner.
  func runPostbuildScript() -> Result<Void, ScriptRunnerError> {
    let script = packageDirectory.appendingPathComponent("postbuild.sh")
    return Self.runScript(script)
  }
  
  /// Runs the prebuild script in the package of this script runner if it exists.
  /// - Returns: Returns a failure if the script exists and fails to run.
  func runPrebuildScriptIfPresent() -> Result<Void, ScriptRunnerError> {
    runPrebuildScript()
      .flatMapError { error in
        if case ScriptRunnerError.scriptDoesntExist(_) = error {
          return .success()
        } else {
          return .failure(error)
        }
      }
  }
  
  /// Runs the postbuild script in the package of this script runner if it exists.
  /// - Returns: Returns a failure if the script exists and fails to run.
  func runPostbuildScriptIfPresent() -> Result<Void, ScriptRunnerError> {
    runPostbuildScript()
      .flatMapError { error in
        if case ScriptRunnerError.scriptDoesntExist(_) = error {
          return .success()
        } else {
          return .failure(error)
        }
      }
  }
  
  /// Runs a shell script.
  /// - Parameter url: The url to the shell script.
  /// - Throws: Throws an error if the script doesn't exist or the script returns a non-zero exit status.
  static func runScript(_ url: URL) -> Result<Void, ScriptRunnerError> {
    guard FileManager.default.itemExists(at: url, withType: .file) else {
      return .failure(ScriptRunnerError.scriptDoesntExist(url))
    }
    
    let process = Process.create("/bin/sh", arguments: [url.path], directory: url.deletingLastPathComponent())
    return process.runAndWait()
      .mapError { error in
        .failedToRunScript(error)
      }
  }
}
