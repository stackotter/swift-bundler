import ArgumentParser
import Foundation

/// The command for migrating project config files to the latest format.
struct MigrateCommand: Command {
  static var configuration = CommandConfiguration(
    commandName: "migrate",
    abstract: "Migrate a project's config file to the latest format."
  )

  /// The directory containing the package to build.
  @Option(
    name: [.customShort("d"), .customLong("directory")],
    help: "The directory containing the package to build.",
    transform: URL.init(fileURLWithPath:))
  var packageDirectory: URL?

  func wrappedRun() async throws {
    try await PackageConfiguration.load(
      fromDirectory: packageDirectory ?? URL(fileURLWithPath: "."),
      migrateConfiguration: true
    ).unwrap()

    log.info("Successfully migrated configuration to the latest format.")
  }
}
