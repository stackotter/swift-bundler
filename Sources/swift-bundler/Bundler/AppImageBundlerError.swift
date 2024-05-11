import Foundation

/// An error returned by ``AppImageBundler``.
enum AppImageBundlerError: LocalizedError {
  case failedToCreateAppDirSkeleton(directory: URL, Error)
  case failedToCopyExecutable(source: URL, destination: URL, Error)
  case failedToCopyIcon(source: URL, destination: URL, Error)
  case failedToCreateDesktopFile(URL, Error?)
  case failedToCreateSymlink(source: URL, destination: URL, Error)
  case failedToBundleAppDir(AppImageToolError)

  var errorDescription: String? {
    switch self {
      case .failedToCreateAppDirSkeleton(let directory, _):
        return "Failed to create app bundle directory structure at '\(directory)'"
      case .failedToCopyExecutable(let source, let destination, _):
        return
          "Failed to copy executable from '\(source.relativePath)' to '\(destination.relativePath)'"
      case .failedToCopyIcon(let source, let destination, _):
        return
          "Failed to copy 'icns' file from '\(source.relativePath)' to '\(destination.relativePath)'"
      case .failedToCreateDesktopFile(let file, _):
        return "Failed to create desktop file at '\(file.relativePath)'"
      case .failedToCreateSymlink(let source, let destination, _):
        return
          "Failed to create symlink from '\(source.relativePath)' to '\(destination.relativePath)'"
      case .failedToBundleAppDir(let error):
        return "Failed to convert AppDir to AppImage: \(error)"
    }
  }
}
