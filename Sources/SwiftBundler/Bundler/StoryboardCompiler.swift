import Foundation

/// A utility for compiling storyboards.
enum StoryboardCompiler {
  /// Compiles all storyboards present within the top level of a directory.
  /// - Parameters:
  ///   - directory: The directory to find storyboards in.
  ///   - outputDirectory: The directory to output the compiled storyboards to.
  ///     Will be created if it doesn't exist.
  ///   - keepSources: If `false`, sources will be deleted after compilation.
  static func compileStoryboards(
    in directory: URL,
    to outputDirectory: URL,
    keepSources: Bool = true
  ) async throws(Error) {
    let contents = try FileManager.default.contentsOfDirectory(
      at: directory,
      errorMessage: ErrorMessage.failedToEnumerateStoryboards
    )

    let storyboards = contents.filter { file in
      file.pathExtension == "storyboard"
    }

    guard !storyboards.isEmpty else {
      return
    }

    if !outputDirectory.exists(withType: .directory) {
      try FileManager.default.createDirectory(
        at: outputDirectory,
        errorMessage: ErrorMessage.failedToCreateOutputDirectory
      )
    }

    // Compile the storyboards and delete the original files if !keepSources
    for storyboard in storyboards {
      try await compileStoryboard(storyboard, to: outputDirectory)

      if !keepSources {
        try FileManager.default.removeItem(
          at: storyboard,
          errorMessage: ErrorMessage.failedToDeleteStoryboard
        )
      }
    }
  }

  /// Compiles a storyboard.
  /// - Parameters:
  ///   - storyboard: The storyboard to compile.
  ///   - directory: The directory to output the compiled storyboard to.
  static func compileStoryboard(
    _ storyboard: URL,
    to directory: URL
  ) async throws(Error) {
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

    do {
      try await process.runAndWait()
    } catch {
      throw Error(.failedToRunIBTool(storyboard: storyboard), cause: error)
    }
  }
}
