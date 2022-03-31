import Foundation

/// A utility for compiling metal shader source files.
enum MetalCompiler {
  /// Compiles any metal shaders present in a directory into a `default.metallib` file (in the same directory).
  /// - Parameters:
  ///   - directory: The directory to compile shaders from.
  ///   - keepSources: If `false`, the sources will get deleted after compilation.
  /// - Returns: If an error occurs, a failure is returned.
  static func compileMetalShaders(in directory: URL, keepSources: Bool) -> Result<Void, MetalCompilerError> {
    guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: []) else {
      return .failure(.failedToEnumerateShaders(directory: directory))
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
            return .failure(.failedToDeleteShaderSource(source, error))
          }
        }

        return .success()
      }
  }

  /// Compiles a list of metal source files into a `metallib` file.
  /// - Parameters:
  ///   - sources: The source files to comile.
  ///   - destination: The directory to output `default.metallib` to.
  /// - Returns: Returns the location of the resulting `metallib`. If an error occurs, a failure is returned.
  static func compileMetalShaders(_ sources: [URL], destination: URL) -> Result<URL, MetalCompilerError> {
    // Create a temporary directory for compilation
    let tempDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("metal_compilation-\(UUID().uuidString)")
    do {
      try FileManager.default.createDirectory(at: tempDirectory)
    } catch {
      return .failure(.failedToCreateTemporaryCompilationDirectory(tempDirectory, error))
    }

    // Compile the shaders into `.air` files
    var airFiles: [URL] = []
    for shaderSource in sources {
      let outputFileName = shaderSource.deletingPathExtension().appendingPathExtension("air").lastPathComponent
      let outputFile = tempDirectory.appendingPathComponent(outputFileName)
      if case let .failure(error) = compileShader(shaderSource, to: outputFile) {
        return .failure(error)
      }
      airFiles.append(outputFile)
    }

    // Combine the compiled shaders into a `.metal-ar` archive
    let archive = tempDirectory.appendingPathComponent("default.metal-ar")
    let archiveResult = createArchive(at: archive, from: airFiles)
    if case let .failure(error) = archiveResult {
      return .failure(error)
    }

    // Convert the `metal-ar` archive into a `metallib` library
    let library = destination.appendingPathComponent("default.metallib")
    let libraryResult = createLibrary(at: library, from: archive)
    if case let .failure(error) = libraryResult {
      return .failure(error)
    }

    return .success(library)
  }

  /// Compiles a metal shader file into an `air` file.
  /// - Parameters:
  ///   - shader: The shader file to compile.
  ///   - outputFile: The resulting `air` file.
  /// - Returns: If an error occurs, a failure is returned.
  static func compileShader(_ shader: URL, to outputFile: URL) -> Result<Void, MetalCompilerError> {
    let process = Process.create(
      "/usr/bin/xcrun",
      arguments: [
        "-sdk", "macosx", "metal",
        "-o", outputFile.path,
        "-c", shader.path
      ])

    let result = process.runAndWait()
    if case let .failure(error) = result {
      return .failure(.failedToCompileShader(shader, error))
    }

    return .success()
  }

  /// Creates a metal archive (a `metal-ar` file) from a list of `air` files (which can be created by ``compileShader(_:outputDirectory:)``).
  /// - Parameters:
  ///   - archive: The resulting `metal-ar` file.
  ///   - airFiles: The air files to create an archive from.
  /// - Returns: If an error occurs, a failure is returned.
  static func createArchive(at archive: URL, from airFiles: [URL]) -> Result<Void, MetalCompilerError> {
    let process = Process.create(
      "/usr/bin/xcrun",
      arguments: [
        "-sdk", "macosx", "metal-ar",
        "rcs", archive.path
      ] + airFiles.map(\.path))

    let result = process.runAndWait()
    if case let .failure(error) = result {
      return .failure(.failedToCreateMetalArchive(error))
    }

    return .success()
  }

  static func createLibrary(at library: URL, from archive: URL) -> Result<Void, MetalCompilerError> {
    let libraryCreationProcess = Process.create(
      "/usr/bin/xcrun",
      arguments: [
        "-sdk", "macosx", "metallib",
        archive.path,
        "-o", library.path
      ])

    let libraryCreationResult = libraryCreationProcess.runAndWait()
    if case let .failure(error) = libraryCreationResult {
      return .failure(.failedToCreateMetalLibrary(error))
    }

    return .success()
  }
}
