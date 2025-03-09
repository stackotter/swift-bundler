import Foundation

/// A utility for compiling storyboards.
enum StoryboardCompiler {
  /// Compiles all storyboards present within the top level of a directory.
  /// - Parameters:
  ///   - directory: The directory to find storyboards in.
  ///   - outputDirectory: The directory to output the compiled storyboards to. Will be created if it doesn't exist.
  ///   - keepSources: If `false`, sources will be deleted after compilation.
  /// - Returns: A failure if an error occurs.
  static func compileStoryboards(
    in directory: URL,
    to outputDirectory: URL,
    keepSources: Bool = true
  ) async -> Result<Void, StoryboardCompilerError> {
    let contents: [URL]
    do {
      contents = try FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil
      )
    } catch {
      return .failure(.failedToEnumerateStoryboards(directory, error))
    }

    let storyboards = contents.filter { file in
      file.pathExtension == "storyboard"
    }

    guard !storyboards.isEmpty else {
      return .success()
    }

    let outputDirectoryExists = FileManager.default.itemExists(
      at: outputDirectory,
      withType: .directory
    )

    return await FileManager.default.contentsOfDirectory(
      at: directory,
      onError: StoryboardCompilerError.failedToEnumerateStoryboards
    ).map { files in
      files.filter { file in
        file.pathExtension == "storyboard"
      }
    }.andThenDoSideEffect(if: !outputDirectoryExists) { _ in
      FileManager.default.createDirectory(
        at: outputDirectory,
        onError: StoryboardCompilerError.failedToCreateOutputDirectory
      )
    }.andThen { storyboards in
      await storyboards.tryForEach { storyboard in
        // Compile the storyboard and delete the original file if !keepSources
        await compileStoryboard(storyboard, to: outputDirectory)
          .andThen(if: !keepSources) { _ in
            FileManager.default.removeItem(
              at: storyboard,
              onError: StoryboardCompilerError.failedToDeleteStoryboard
            )
          }
      }
    }
  }

  /// Compiles a storyboard.
  /// - Parameters:
  ///   - storyboard: The storyboard to compile.
  ///   - directory: The directory to output the compiled storyboard to.
  /// - Returns: A failure if an error occurs.
  static func compileStoryboard(
    _ storyboard: URL,
    to directory: URL
  ) async -> Result<Void, StoryboardCompilerError> {
    let outputFile =
      directory
      .appendingPathComponent(storyboard.deletingPathExtension().lastPathComponent)
      .appendingPathExtension("storyboardc")

    let process = Process.create(
      "/usr/bin/ibtool",
      arguments: [
        "--compile", outputFile.path,
        storyboard.path,
      ]
    )

    return await process.runAndWait().mapError { error in
      return .failedToRunIBTool(storyboard: storyboard, error)
    }
  }
}
