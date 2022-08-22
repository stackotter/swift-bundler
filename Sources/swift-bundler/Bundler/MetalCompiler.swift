import Foundation

/// A utility for compiling metal shader source files.
enum MetalCompiler {
  /// Compiles any metal shaders present in a directory into a `default.metallib` file (in the same directory).
  /// - Parameters:
  ///   - directory: The directory to compile shaders from.
  ///   - minimumMacOSVersion: The macOS version that the built shaders should target.
  ///   - keepSources: If `false`, the sources will get deleted after compilation.
  ///   - platform: The platform to compile for.
  /// - Returns: If an error occurs, a failure is returned.
  static func compileMetalShaders(
    in directory: URL,
    for platform: Platform,
    keepSources: Bool
  ) -> Result<Void, MetalCompilerError> {
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
    return compileMetalShaders(shaderSources, to: directory, for: platform).flatMap { _ in
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
  ///   - platform: The platform to compile for.
  /// - Returns: Returns the location of the resulting `metallib`. If an error occurs, a failure is returned.
  static func compileMetalShaders(
    _ sources: [URL],
    to destination: URL,
    for platform: Platform
  ) -> Result<URL, MetalCompilerError> {
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
      if case let .failure(error) = compileShader(shaderSource, to: outputFile, for: platform) {
        return .failure(error)
      }
      airFiles.append(outputFile)
    }

    // Combine the compiled shaders into a `.metal-ar` archive
    let archive = tempDirectory.appendingPathComponent("default.metal-ar")
    let archiveResult = createArchive(at: archive, from: airFiles, for: platform)
    if case let .failure(error) = archiveResult {
      return .failure(error)
    }

    // Convert the `metal-ar` archive into a `metallib` library
    let library = destination.appendingPathComponent("default.metallib")
    let libraryResult = createLibrary(at: library, from: archive, for: platform)
    if case let .failure(error) = libraryResult {
      return .failure(error)
    }

    return .success(library)
  }

  /// Compiles a metal shader file into an `air` file.
  /// - Parameters:
  ///   - shader: The shader file to compile.
  ///   - outputFile: The resulting `air` file.
  ///   - platform: The platform to build for.
  /// - Returns: If an error occurs, a failure is returned.
  static func compileShader(
    _ shader: URL,
    to outputFile: URL,
    for platform: Platform
  ) -> Result<Void, MetalCompilerError> {
    let process = Process.create(
      "/usr/bin/xcrun",
      arguments: [
        "-sdk", platform.sdkName, "metal",
        // "-mmacosx-version-min=\(minimumMacOSVersion)", // TODO: re-enable this code and get it working with the new platform versioning system
        "-o", outputFile.path,
        "-c", shader.path,
        "-gline-tables-only", // TODO: disable these in distribution builds
        "-frecord-sources"
      ]
    )

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
  ///   - platform: The platform to archive for.
  /// - Returns: If an error occurs, a failure is returned.
  static func createArchive(
    at archive: URL,
    from airFiles: [URL],
    for platform: Platform
  ) -> Result<Void, MetalCompilerError> {
    let process = Process.create(
      "/usr/bin/xcrun",
      arguments: [
        "-sdk", platform.sdkName, "metal-ar",
        "rcs", archive.path
      ] + airFiles.map(\.path)
    )

    let result = process.runAndWait()
    if case let .failure(error) = result {
      return .failure(.failedToCreateMetalArchive(error))
    }

    return .success()
  }

  /// Creates a metal library from a metal archive.
  /// - Parameters:
  ///   - library: The output file location.
  ///   - archive: The archive to convert.
  ///   - platform: The platform to create the library for.
  // - Returns: If an error occurs, a failure is returned.
  static func createLibrary(
    at library: URL,
    from archive: URL,
    for platform: Platform
  ) -> Result<Void, MetalCompilerError> {
    let libraryCreationProcess = Process.create(
      "/usr/bin/xcrun",
      arguments: [
        "-sdk", platform.sdkName, "metallib",
        archive.path,
        "-o", library.path
      ]
    )

    let libraryCreationResult = libraryCreationProcess.runAndWait()
    if case let .failure(error) = libraryCreationResult {
      return .failure(.failedToCreateMetalLibrary(error))
    }

    return .success()
  }
}
