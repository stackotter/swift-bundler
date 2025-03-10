import Foundation

/// A utility for compiling metal shader source files.
enum MetalCompiler {
  /// Compiles any metal shaders present in a directory into a `default.metallib` file (in the same directory).
  /// - Parameters:
  ///   - directory: The directory to compile shaders from.
  ///   - platform: The platform to compile for.
  ///   - platformVersion: The platform version to target during compilation.
  ///   - keepSources: If `false`, the sources will get deleted after compilation.
  /// - Returns: If an error occurs, a failure is returned.
  static func compileMetalShaders(
    in directory: URL,
    for platform: Platform,
    platformVersion: String,
    keepSources: Bool
  ) async -> Result<Void, MetalCompilerError> {
    guard
      let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [])
    else {
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
    return await compileMetalShaders(
      shaderSources,
      to: directory,
      for: platform,
      platformVersion: platformVersion
    )
    .replacingSuccessValue(with: ())
    .andThen(if: !keepSources) { _ in
      shaderSources.tryForEach { source in
        FileManager.default.removeItem(at: source)
          .mapError { error in
            .failedToDeleteShaderSource(source, error)
          }
      }
    }
  }

  /// Compiles a list of metal source files into a `metallib` file.
  /// - Parameters:
  ///   - sources: The source files to comile.
  ///   - destination: The directory to output `default.metallib` to.
  ///   - platform: The platform to compile for.
  ///   - platformVersion: The platform version to target during compilation.
  /// - Returns: Returns the location of the resulting `metallib`. If an error
  ///   occurs, a failure is returned.
  static func compileMetalShaders(
    _ sources: [URL],
    to destination: URL,
    for platform: Platform,
    platformVersion: String
  ) async -> Result<URL, MetalCompilerError> {
    // Create a temporary directory for compilation
    let tempDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("metal_compilation-\(UUID().uuidString)")
    let archive = tempDirectory.appendingPathComponent("default.metal-ar")

    return await FileManager.default.createDirectory(
      at: tempDirectory,
      onError: MetalCompilerError.failedToCreateTemporaryCompilationDirectory
    )
    .andThen { _ in
      // Compile the shaders into `.air` files
      await sources.tryMap { shaderSource in
        let outputFileName = shaderSource.deletingPathExtension()
          .appendingPathExtension("air").lastPathComponent
        let outputFile = tempDirectory.appendingPathComponent(outputFileName)

        return await compileShader(
          shaderSource,
          to: outputFile,
          for: platform,
          platformVersion: platformVersion
        ).replacingSuccessValue(with: outputFile)
      }
    }
    .andThen { airFiles in
      // Combine the compiled shaders into a `.metal-ar` archive
      await createArchive(at: archive, from: airFiles, for: platform)
    }
    .andThen { _ in
      // Convert the `metal-ar` archive into a `metallib` library
      let library = destination.appendingPathComponent("default.metallib")
      return await createLibrary(at: library, from: archive, for: platform)
        .replacingSuccessValue(with: library)
    }
  }

  /// Compiles a metal shader file into an `air` file.
  /// - Parameters:
  ///   - shader: The shader file to compile.
  ///   - outputFile: The resulting `air` file.
  ///   - platform: The platform to build for.
  ///   - platformVersion: The platform version to target during compilation.
  /// - Returns: If an error occurs, a failure is returned.
  static func compileShader(
    _ shader: URL,
    to outputFile: URL,
    for platform: Platform,
    platformVersion: String
  ) async -> Result<Void, MetalCompilerError> {
    var arguments = [
      "-sdk", platform.sdkName, "metal",
      "-o", outputFile.path,
      "-c", shader.path,
      "-gline-tables-only",  // TODO: disable these in distribution builds
      "-frecord-sources",
    ]

    switch platform {
      case .macOS:
        arguments.append("-mmacosx-version-min=\(platformVersion)")
      case .iOS:
        arguments.append("-mios-version-min=\(platformVersion)")
      default:
        // TODO: Figure out whether any other platforms require/have a minimum platform version option
        break
    }

    let process = Process.create(
      "/usr/bin/xcrun",
      arguments: arguments,
      runSilentlyWhenNotVerbose: false
    )

    let result = await process.runAndWait()
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
  ) async -> Result<Void, MetalCompilerError> {
    let process = Process.create(
      "/usr/bin/xcrun",
      arguments: [
        "-sdk", platform.sdkName, "metal-ar",
        "rcs", archive.path,
      ] + airFiles.map(\.path)
    )

    let result = await process.runAndWait()
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
  ) async -> Result<Void, MetalCompilerError> {
    let libraryCreationProcess = Process.create(
      "/usr/bin/xcrun",
      arguments: [
        "-sdk", platform.sdkName, "metallib",
        archive.path,
        "-o", library.path,
      ]
    )

    let libraryCreationResult = await libraryCreationProcess.runAndWait()
    if case let .failure(error) = libraryCreationResult {
      return .failure(.failedToCreateMetalLibrary(error))
    }

    return .success()
  }
}
