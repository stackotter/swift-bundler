import Foundation

/// A general tool for working with various archive formats.
enum ArchiveTool {
  /// Creates a `.tar.gz` archive of the given directory.
  static func createTarGz(
    of directory: URL,
    at outputFile: URL
  ) async throws(Error) {
    let arguments = ["--create", "--file", outputFile.path, directory.lastPathComponent]
    let workingDirectory = directory.deletingLastPathComponent()

    do {
      try await Process.create(
        "tar",
        arguments: arguments,
        directory: workingDirectory
      ).runAndWait()
    } catch {
      throw Error(
        .failedToCreateTarGz(directory: directory, outputFile: outputFile),
        cause: error
      )
    }
  }
}
