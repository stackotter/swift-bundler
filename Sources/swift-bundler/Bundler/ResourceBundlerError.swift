import Foundation

/// An error returned by ``ResourceBundler``.
enum ResourceBundlerError: LocalizedError {
  case failedToEnumerateBundles(directory: URL, Error)
  case failedToCopyBundle(source: URL, destination: URL, Error)
  case failedToCreateBundleDirectory(URL, Error)
  case failedToCreateInfoPlist(file: URL, PlistCreatorError)
  case failedToCopyResource(source: URL, destination: URL, Error)
  case failedToEnumerateBundleContents(directory: URL, Error)
  case failedToCompileMetalShaders(MetalCompilerError)
  case failedToCompileXCAssets(ProcessError)
  case failedToDeleteAssetCatalog(Error)
  case failedToCompileStoryboards(StoryboardCompilerError)

  var errorDescription: String? {
    switch self {
      case .failedToEnumerateBundles(let directory, _):
        return "Failed to enumerate bundles in directory at '\(directory.relativePath)'"
      case .failedToCopyBundle(let source, let destination, _):
        return "Failed to copy bundle from '\(source.relativePath)' to '\(destination.relativePath)'"
      case .failedToCreateBundleDirectory(let directory, _):
        return "Failed to create bundle directory at '\(directory.relativePath)'"
      case .failedToCreateInfoPlist(let file, let plistCreatorError):
        return "Failed to create bundle 'Info.plist' at \(file.relativePath): \(plistCreatorError.localizedDescription)"
      case .failedToCopyResource(let source, let destination, _):
        return "Failed to copy resource from '\(source.relativePath)' to '\(destination.relativePath)'"
      case .failedToEnumerateBundleContents(let directory, _):
        return "Failed to enumerate bundle contents at '\(directory.relativePath)'"
      case .failedToCompileMetalShaders(let metalCompilerError):
        return "Failed to compile Metal shaders: \(metalCompilerError.localizedDescription)"
      case .failedToCompileXCAssets(let error):
        return "Failed to compile XCAssets with 'actool': \(error)"
      case .failedToDeleteAssetCatalog:
        return "Failed to delete asset catalog after compilation"
      case .failedToCompileStoryboards(let error):
        return error.localizedDescription
    }
  }
}
