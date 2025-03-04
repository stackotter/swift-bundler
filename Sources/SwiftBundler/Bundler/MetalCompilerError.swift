import Foundation

/// An error returned by ``MetalCompiler``.
enum MetalCompilerError: LocalizedError {
  case failedToCreateTemporaryCompilationDirectory(URL, Error)
  case failedToCompileShader(URL, ProcessError)
  case failedToCreateMetalArchive(ProcessError)
  case failedToCreateMetalLibrary(ProcessError)
  case failedToDeleteShaderSource(URL, Error)
  case failedToEnumerateShaders(directory: URL)

  var errorDescription: String? {
    switch self {
      case .failedToCreateTemporaryCompilationDirectory(let directory, _):
        return
          "Failed to create a temporary directory for shader compilation at '\(directory.relativePath)'"
      case .failedToCompileShader(let file, let processError):
        return
          "Failed to compile shader source file '\(file)': \(processError.localizedDescription)"
      case .failedToCreateMetalArchive(let processError):
        return
          "Failed to create a metal archive from compiled source files: \(processError.localizedDescription)"
      case .failedToCreateMetalLibrary(let processError):
        return
          "Failed to create a metal library from the metal archive: \(processError.localizedDescription)"
      case .failedToDeleteShaderSource(let file, _):
        return "Failed to delete the shader source file at '\(file.relativePath)' after compilation"
      case .failedToEnumerateShaders(let directory):
        return "Failed to enumerate shaders in directory '\(directory.relativePath)'"
    }
  }
}
