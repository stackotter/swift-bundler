import Foundation

/// An error returned by ``DynamicLibraryBundler``.
enum DynamicLibraryBundlerError: LocalizedError {
  case failedToEnumerateDynamicLibraries(directory: URL, Error)
  case failedToCopyDynamicLibrary(source: URL, destination: URL, Error)
  case failedToUpdateLibraryInstallName(
    library: String?,
    original: String,
    new: String, ProcessError
  )
  case failedToUpdateAppRPath(original: String, new: String, ProcessError)
  case failedToEnumerateSystemWideDynamicDependencies(ProcessError)
  case failedToSignMovedLibrary(CodeSignerError)

  var errorDescription: String? {
    switch self {
      case .failedToEnumerateDynamicLibraries(let directory, _):
        return "Failed to enumerate dynamic libraries in '\(directory.relativePath)'"
      case .failedToCopyDynamicLibrary(let source, let destination, _):
        return
          "Failed to copy dynamic library from '\(source.relativePath)' to '\(destination.relativePath)'"
      case .failedToUpdateLibraryInstallName(let library, let original, let new, let processError):
        let extraInfo = library.map { "of '\($0)'" } ?? ""
        return
          "Failed to update dynamic library install name\(extraInfo) from '\(original)' to '\(new)': \(processError.localizedDescription)"
      case .failedToUpdateAppRPath(let original, let new, let processError):
        return
          "Failed to update the app's rpath from '\(original)' to '\(new)': \(processError.localizedDescription)"
      case .failedToEnumerateSystemWideDynamicDependencies(let processError):
        return
          "Failed to enumerate system wide dynamic libraries depended on by the built executable: \(processError.localizedDescription)"
      case .failedToSignMovedLibrary:
        return "Failed to sign relocated dynamic library using the ad-hoc signing method"
    }
  }
}
