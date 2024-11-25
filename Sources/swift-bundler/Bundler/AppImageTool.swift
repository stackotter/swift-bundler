import Foundation

#if os(Linux)
  import Glibc
#endif

/// A swifty interface for the `appimagetool` command-line tool for converting AppDirs to
/// AppImages.
enum AppImageTool {
  static func bundle(appDir: URL) -> Result<Void, AppImageToolError> {
    let appImage = appDir.deletingPathExtension().appendingPathExtension("AppImage")

    // I have no clue why `appimagetool` specifically has this issue, but if
    // run `appimagetool` via `Swift.Process` on Linux, then the tool's process
    // never terminates even once the tool has clearly finished. This occurs
    // regardless of whether any pipes are hooked up to the `appimagetool`
    // process, meaning that even the most barebones `Swift.Process` usage
    // faces this issue. Therefore on Linux I've hacked together a *hopefully*
    // safe `execv` wrapper.
    #if os(Linux)
      let childPid = fork()
      if childPid == 0 {
        let cArguments =
          arguments.map { strdup($0) }
          + [UnsafeMutablePointer<CChar>(bitPattern: 0)]
        execv("/usr/bin/env", cArguments)
        // We only ever get here if the execv fails
        Foundation.exit(-1)
      } else {
        var status: Int32 = 0
        waitpid(childPid, &status, 0)
        if status != 0 {
          return .failure(
            .failedToRunAppImageTool(
              command: "appimagetool \(arguments.joined(separator: " "))",
              ProcessError.nonZeroExitStatus(Int(status))
            )
          )
        } else {
          return .success()
        }
      }
    #else
      let arguments = [appDir.path, appImage.path]
      let process = Process.create(
        "bash",
        arguments: ["-c", "appimagetool " + arguments.joined(separator: " ")],
        runSilentlyWhenNotVerbose: false
      )

      return process.runAndWait()
        .mapError { error in
          .failedToRunAppImageTool(
            command: "appimagetool \(arguments.joined(separator: " "))",
            error
          )
        }
    #endif
  }
}
