import Foundation

/// An error returned by ``AppImageBundler``.
enum AppImageBundlerError: LocalizedError {
  case failedToCreateAppDirSkeleton(directory: URL, Error)
  case failedToCopyExecutable(source: URL, destination: URL, Error)
  case failedToCopyIcon(source: URL, destination: URL, Error)
  case failedToCreateDesktopFile(URL, Error?)
  case failedToCreateSymlink(source: URL, relativeDestination: String, Error)
  case failedToBundleAppDir(AppImageToolError)
  case failedToCopyResourceBundle(source: URL, destination: URL, Error)
  case failedToEnumerateResourceBundles(directory: URL, Error)
  case failedToEnumerateDynamicDependencies(ProcessError)
  case failedToCopyDynamicLibrary(source: URL, destination: URL, Error)
  case failedToUpdateMainExecutableRunpath(executable: URL, Error?)

  var errorDescription: String? {
    switch self {
      case .failedToCreateAppDirSkeleton(let directory, _):
        return "Failed to create app bundle directory structure at '\(directory)'"
      case .failedToCopyExecutable(let source, let destination, _):
        return """
          Failed to copy executable from '\(source.relativePath)' to \
          '\(destination.relativePath)'
          """
      case .failedToCopyIcon(let source, let destination, _):
        return """
          Failed to copy 'icns' file from '\(source.relativePath)' to \
          '\(destination.relativePath)'
          """
      case .failedToCreateDesktopFile(let file, _):
        return "Failed to create desktop file at '\(file.relativePath)'"
      case .failedToCreateSymlink(let source, let destination, _):
        return """
          Failed to create symlink from '\(source.relativePath)' to relative \
          path '\(destination)'
          """
      case .failedToBundleAppDir(let error):
        return "Failed to convert AppDir to AppImage: \(error)"
      case .failedToCopyResourceBundle(let source, let destination, _):
        return """
          Failed to copy resource bundle at '\(source.relativePath)' to \
          '\(destination.relativePath)'
          """
      case .failedToEnumerateResourceBundles(let directory, _):
        return "Failed to enumerate resource bundles in '\(directory.relativePath)'"
      case .failedToEnumerateDynamicDependencies:
        return "Failed to enumerate dynamically linked dependencies of main executable"
      case .failedToCopyDynamicLibrary(let source, let destination, _):
        return """
          Failed to copy dynamic library from '\(source.relativePath)' to \
          '\(destination.relativePath)'
          """
      case .failedToUpdateMainExecutableRunpath(let executable, let underlyingError):
        let reason = underlyingError?.localizedDescription ?? "unknown reason"
        return """
          Failed to update the runpath of the main executable at \
          '\(executable.relativePath)': \(reason)
          """
    }
  }
}
