import Foundation

/// An error returned by ``GenericLinuxBundler``.
enum GenericLinuxBundlerError: LocalizedError {
  case failedToCreateBundleStructure(root: URL, Error)
  case failedToCopyExecutable(source: URL, destination: URL, Error)
  case failedToCopyIcon(source: URL, destination: URL, Error)
  case failedToCreateDesktopFile(URL, Error?)
  case failedToCreateSymlink(source: URL, relativeDestination: String, Error)
  case failedToCopyResourceBundle(source: URL, destination: URL, Error)
  case failedToEnumerateResourceBundles(directory: URL, Error)
  case failedToEnumerateDynamicDependencies(Error)
  case failedToCopyDynamicLibrary(source: URL, destination: URL, Error)
  case failedToUpdateMainExecutableRunpath(executable: URL, Error)
  case failedToCreateDirectory(URL, Error)

  var errorDescription: String? {
    switch self {
      case .failedToCreateBundleStructure(let root, _):
        return "Failed to create app bundle directory structure at '\(root)'"
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
        return """
          Failed to update the runpath of the main executable at \
          '\(executable.relativePath)': \(underlyingError.localizedDescription)
          """
      case .failedToCreateDirectory(let directory, _):
        return "Failed to create directory at '\(directory.relativePath)'"
    }
  }
}
