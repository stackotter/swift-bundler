import Foundation

/// A swifty interface for the `appimagetool` command-line tool for converting AppDirs to
/// AppImages.
enum AppImageTool {
  static func bundle(appDir: URL, to appImage: URL) async -> Result<Void, AppImageToolError> {
    let arguments = [appDir.path, appImage.path]
    return await Process.runAppImage("appimagetool", arguments: arguments)
      .mapError { error in
        .failedToRunAppImageTool(
          command: "appimagetool \(arguments.joined(separator: " "))",
          error
        )
      }
  }
}
