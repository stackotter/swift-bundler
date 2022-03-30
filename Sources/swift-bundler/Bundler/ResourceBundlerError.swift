import Foundation

/// An error returned by ``ResourceBundler``.
enum ResourceBundlerError: LocalizedError {
  case failedToEnumerateBundles(directory: URL, Error)
  case failedToCopyBundle(source: URL, destination: URL, Error)
  case failedToCreateBundleDirectory(URL, Error)
  case failedToCreateInfoPlist(file: URL, PlistCreatorError)
  case failedToCopyResource(source: URL, destination: URL)
  case failedToEnumerateBundleContents(directory: URL, Error)
  case failedToCompileMetalShaders(MetalCompilerError)
  
  var errorDescription: String? {
    switch self {
      case .failedToEnumerateBundles(let directory, _):
        return "Failed to enumerate bundles in directory at '\(directory)'"
      case .failedToCopyBundle(let source, let destination, _):
        return "Failed to copy bundle from '\(source)' to '\(destination)'"
      case .failedToCreateBundleDirectory(let directory, _):
        return "Failed to create bundle directory at '\(directory)'"
      case .failedToCreateInfoPlist(let file, let plistCreatorError):
        return "Failed to create bundle 'Info.plist' at \(file): \(plistCreatorError.localizedDescription)"
      case .failedToCopyResource(let source, let destination):
        return "Failed to copy resource from '\(source)' to '\(destination)'"
      case .failedToEnumerateBundleContents(let directory, _):
        return "Failed to enumerate bundle contents at '\(directory)'"
      case .failedToCompileMetalShaders(let metalCompilerError):
        return "Failed to compile Metal shaders: \(metalCompilerError.localizedDescription)"
    }
  }
}
