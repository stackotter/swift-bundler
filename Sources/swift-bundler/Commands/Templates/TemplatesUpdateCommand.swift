import Foundation
import ArgumentParser

/// The subcommand for updating the default templates repository.
struct TemplatesUpdateCommand: Command {
  static var configuration = CommandConfiguration(
    commandName: "update",
    abstract: "Update the default templates to the latest version.")

  func wrappedRun() throws {
    try Templater.updateTemplates().unwrap()

    log.info("Done")
  }
}
