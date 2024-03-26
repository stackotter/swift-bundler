import Foundation

/// A swifty interface for the `appimagetool` command-line tool for converting AppDirs to
/// AppImages.
enum AppImageTool {
  static func bundle(appDir: URL) -> Result<Void, AppImageToolError> {
    let appImage = appDir.deletingPathExtension().appendingPathExtension("AppImage")

    let arguments = [appDir.path, appImage.path]
    let process = Process.create(
      "appimagetool",
      arguments: arguments,
      runSilentlyWhenNotVerbose: false
    )

    return process.runAndWait()
      .mapError { error in
        .failedToRunAppImageTool(
          command: "appimagetool \(arguments.joined(separator: " "))",
          error
        )
      }
  }
}
