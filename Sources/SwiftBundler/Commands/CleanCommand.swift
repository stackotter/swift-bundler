import ArgumentParser
import Foundation

/// The command for cleaning scratch files and caches.
struct CleanCommand: Command {
  static var configuration = CommandConfiguration(
    commandName: "clean",
    abstract: "Clean a project's scratch directory."
  )

  /// The directory containing the package to build.
  @Option(
    name: [.customShort("d"), .customLong("directory")],
    help: "The directory containing the package to build.",
    transform: URL.init(fileURLWithPath:))
  var packageDirectory: URL?

  /// A custom scratch directory to clean. Defaults to `.build`.
  @Option(
    name: .customLong("scratch-path"),
    help: "A custom scratch directory path (default: .build)",
    transform: URL.init(fileURLWithPath:))
  var scratchDirectory: URL?

  func wrappedRun() async throws {
    let packageDirectory = packageDirectory ?? URL.currentDirectory
    let scratchDirectory = scratchDirectory ?? (packageDirectory / ".build")
    try Process.create(
      "swift",
      arguments: [
        "package",
        "--scratch-path",
        scratchDirectory.path,
        "clean"
      ]
    )

    let outputDirectory = BundleCommand.outputDirectory(for: scratchDirectory)
    if outputDirectory.exists() {
      try FileManager.default.removeItem(at: outputDirectory)
    }
  }
}

