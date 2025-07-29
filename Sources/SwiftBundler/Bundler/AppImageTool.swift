import Foundation

/// A swifty interface for the `appimagetool` command-line tool for converting AppDirs to
/// AppImages.
enum AppImageTool {
  static func bundle(appDir: URL, to appImage: URL) async throws(Error) {
    let arguments = [appDir.path, appImage.path]
    try await Error.catch(withMessage: .failedToRunAppImageTool) {
      try await Process.runAppImage("appimagetool", arguments: arguments)
    }
  }
}
