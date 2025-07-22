import Foundation
import ErrorKit

/// An error returned by ``DynamicLibraryBundler``.
enum DynamicLibraryBundlerError: Throwable {
  case failedToEnumerateDynamicLibraries(directory: URL)
  case failedToUpdateLibraryInstallName(binary: URL, original: String, new: String)
  case failedToUpdateAppRPath(binary: URL, original: String, new: String)
  case failedToEnumerateDynamicDependencies(binary: URL)
  case failedToSignMovedLibrary
  case failedToLocateDynamicDependency(installName: String)

  var userFriendlyMessage: String {
    switch self {
      case .failedToEnumerateDynamicLibraries(let directory):
        return "Failed to enumerate dynamic libraries in '\(directory.relativePath)'"
      case .failedToUpdateLibraryInstallName(let binary, let original, let new):
        let binaryPath = binary.path(relativeTo: .currentDirectory)
        return """
          Failed to update dynamic library install name from \
          '\(original)' to '\(new)' in '\(binaryPath)'
          """
      case .failedToUpdateAppRPath(let binary, let original, let new):
        let binaryPath = binary.path(relativeTo: .currentDirectory)
        return "Failed to update the '\(binaryPath)' rpath from '\(original)' to '\(new)'"
      case .failedToEnumerateDynamicDependencies(let binary):
        let binaryPath = binary.path(relativeTo: .currentDirectory)
        return """
          Failed to enumerate dynamic dependencies of '\(binaryPath)'
          """
      case .failedToSignMovedLibrary:
        return "Failed to sign relocated dynamic library using the ad-hoc signing method"
      case .failedToLocateDynamicDependency(let installName):
        return "Failed to locate dynamic dependency with install name '\(installName)'"
    }
  }
}
