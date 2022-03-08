import Foundation

enum MetalCompilerError: LocalizedError {
  case failedToCreateMetalCompilationTempDirectory(Error)
  case failedToCompileMetalShader(String, ProcessError)
  case failedToCreateMetalArchive(ProcessError)
  case failedToCreateMetalLibrary(ProcessError)
  case failedToDeleteShaderSource(String, Error)
  case failedToEnumerateMetalShaders
}

/// A utility for compiling metal shader source files.
enum MetalCompiler {
  /// Compiles any metal shaders present in a directory into a `default.metallib` file (in the same directory).
  /// - Parameters:
  ///   - directory: The directory to compile shaders from.
  ///   - keepSources: If `false`, the sources will get deleted after compilation.
  static func compileMetalShaders(in directory: URL, keepSources: Bool) -> Result<Void, MetalCompilerError> {
    guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: []) else {
      return .failure(.failedToEnumerateMetalShaders)
    }
    
    var shaderSources: [URL] = []
    for case let file as URL in enumerator where file.pathExtension == "metal" {
      shaderSources.append(file)
    }
    
    guard !shaderSources.isEmpty else {
      return .success()
    }
    
    log.info("Compiling metal shaders")
    
    // Compile metal shaders, and if successful, delete all shader sources
    return compileMetalShaders(shaderSources, destination: directory)
      .flatMap { _ in
        if keepSources {
          return .success()
        }
        
        for source in shaderSources {
          do {
            try FileManager.default.removeItem(at: source)
          } catch {
            return .failure(.failedToDeleteShaderSource(source.lastPathComponent, error))
          }
        }
        
        return .success()
      }
  }
  
  /// Compiles a list of metal source files.
  /// - Parameters:
  ///   - sources: The source files to comile.
  ///   - destination: The directory to output the `default.metallib` to.
  static func compileMetalShaders(_ sources: [URL], destination: URL) -> Result<Void, MetalCompilerError> {
    // Create a temporary directory for compilation
    let tempDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("metal_compilation-\(UUID().uuidString)")
    do {
      try FileManager.default.createDirectory(at: tempDirectory)
    } catch {
      return .failure(.failedToCreateMetalCompilationTempDirectory(error))
    }
    
    // Compile the shaders into `.air` files
    for shaderSource in sources {
      let outputFileName = shaderSource.deletingPathExtension().appendingPathExtension("air").lastPathComponent
      
      let process = Process.create(
        "/usr/bin/xcrun",
        arguments: [
          "-sdk", "macosx", "metal",
          "-o", tempDirectory.appendingPathComponent(outputFileName).path,
          "-c", shaderSource.path
        ],
        directory: tempDirectory)
      
      let result = process.runAndWait()
      if case let .failure(error) = result {
        return .failure(.failedToCompileMetalShader(shaderSource.lastPathComponent, error))
      }
    }
    
    // Combine the compiled shaders into a `.metal-ar` archive
    let airFiles = sources
      .map { $0.deletingPathExtension().appendingPathExtension("air") }
      .map { tempDirectory.appendingPathComponent($0.lastPathComponent).path }
    
    var arguments = [
      "-sdk", "macosx", "metal-ar",
      "rcs", "default.metal-ar"]
    arguments.append(contentsOf: airFiles)
    
    let compilationProcess = Process.create(
      "/usr/bin/xcrun",
      arguments: arguments,
      directory: tempDirectory)
    
    let compilationResult = compilationProcess.runAndWait()
    if case let .failure(error) = compilationResult {
      return .failure(.failedToCreateMetalArchive(error))
    }
    
    // Convert the `metal-ar` archive into a `metallib` library
    let libraryCreationProcess = Process.create(
      "/usr/bin/xcrun",
      arguments: [
        "-sdk", "macosx", "metallib",
        "default.metal-ar",
        "-o", destination.appendingPathComponent("default.metallib").path
      ],
      directory: tempDirectory)
    
    let libraryCreationResult = libraryCreationProcess.runAndWait()
    if case let .failure(error) = libraryCreationResult {
      return .failure(.failedToCreateMetalLibrary(error))
    }
    
    return .success()
  }
}
