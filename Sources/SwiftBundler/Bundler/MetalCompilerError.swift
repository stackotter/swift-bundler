import Foundation
import ErrorKit

extension MetalCompiler {
  typealias Error = RichError<ErrorMessage>

  /// An error message related to ``MetalCompiler``.
  enum ErrorMessage: Throwable {
    case failedToCreateTemporaryCompilationDirectory(URL)
    case failedToCompileShader(URL)
    case failedToCreateMetalArchive
    case failedToCreateMetalLibrary
    case failedToDeleteShaderSource(URL)
    case failedToEnumerateShaders(directory: URL)

    var userFriendlyMessage: String {
      switch self {
        case .failedToCreateTemporaryCompilationDirectory(let directory):
          return """
            Failed to create a temporary directory for shader compilation at \
            '\(directory.relativePath)'
            """
        case .failedToCompileShader(let file):
          return
            "Failed to compile shader source file '\(file)'"
        case .failedToCreateMetalArchive:
          return "Failed to create a metal archive from compiled source files"
        case .failedToCreateMetalLibrary:
          return "Failed to create a metal library from the metal archive"
        case .failedToDeleteShaderSource(let file):
          return """
            Failed to delete the shader source file at '\(file.relativePath)' \
            after compilation
            """
        case .failedToEnumerateShaders(let directory):
          return "Failed to enumerate shaders in directory '\(directory.relativePath)'"
      }
    }
  }
}
