import Foundation

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
  ) -> Result<Void, StoryboardCompilerError> {
    let contents: [URL]
    do {
      contents = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
    } catch {
      return .failure(.failedToEnumerateStoryboards(directory, error))
    }

    if !FileManager.default.itemExists(at: outputDirectory, withType: .directory) {
      do {
        try FileManager.default.createDirectory(at: outputDirectory)
      } catch {
        return .failure(.failedToCreateOutputDirectory(outputDirectory, error))
      }
    }

    for file in contents where file.pathExtension == "storyboard" {
      if case .failure(let error) = compileStoryboard(file, to: outputDirectory) {
        return .failure(error)
      }

      if !keepSources {
        do {
          try FileManager.default.removeItem(at: file)
        } catch {
          return .failure(.failedToDeleteStoryboard(file, error))
        }
      }
    }

    return .success()
  }

  /// Compiles a storyboard.
  /// - Parameters:
  ///   - storyboard: The storyboard to compile.
  ///   - directory: The directory to output the compiled storyboard to.
  /// - Returns: A failure if an error occurs.
  static func compileStoryboard(
    _ storyboard: URL,
    to directory: URL
  ) -> Result<Void, StoryboardCompilerError> {
    let outputFile = directory
      .appendingPathComponent(storyboard.deletingPathExtension().lastPathComponent)
      .appendingPathExtension("storyboardc")

    let process = Process.create(
      "/usr/bin/ibtool",
      arguments: [
        "--compile", outputFile.path,
        storyboard.path
      ]
    )

    return process.runAndWait().mapError { error in
      return .failedToRunIBTool(storyboard: storyboard, error)
    }
  }
}
