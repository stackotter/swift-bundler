import Foundation

/// A general tool for working with various archive formats.
enum ArchiveTool {
  /// Creates a `.tar.gz` archive of the given directory.
  static func createTarGz(
    of directory: URL,
    at outputFile: URL
  ) -> Result<Void, ArchiveToolError> {
    let arguments = ["--create", "--file", outputFile.path, directory.lastPathComponent]
    let workingDirectory = directory.deletingLastPathComponent()
    return Process.create("tar", arguments: arguments, directory: workingDirectory)
      .runAndWait()
      .mapError { error in
        .failedToCreateTarGz(directory: directory, outputFile: outputFile, error)
      }
  }
}
