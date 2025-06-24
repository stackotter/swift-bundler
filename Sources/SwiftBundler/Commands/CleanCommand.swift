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

    // Ensure that we're in a Swift package directory.
    let configurationFile = PackageConfiguration.standardConfigurationFileLocation(
      for: packageDirectory
    )
    guard configurationFile.exists() else {
      throw CLIError.missingConfigurationFile(configurationFile)
    }

    // Running 'swift package clean' also clears out '.build/bundler' on our
    // behalf, so we don't need to do anything more.
    let scratchDirectory = scratchDirectory ?? (packageDirectory / ".build")
    try await Process.create(
      "swift",
      arguments: [
        "package",
        "--scratch-path",
        scratchDirectory.path,
        "clean"
      ]
    ).runAndWait().unwrap()
  }
}

