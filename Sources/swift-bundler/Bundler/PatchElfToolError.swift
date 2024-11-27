import Foundation

/// An error thrown by ``PatchElfTool``.
enum PatchElfToolError: LocalizedError {
  case patchelfNotFound(ProcessError)
  case failedToSetRunpath(elfFile: URL, ProcessError)

  var errorDescription: String {
    switch self {
      case .patchelfNotFound:
        return """
          Command 'patchelf' not found, but required by selected bundler. \
          Please install it and try again
          """
      case .failedToSetRunpath(let elfFile, let error):
        return """
          Failed to set runpath of '\(elfFile.path)': \(error.localizedDescription)
          """
    }
  }
}
