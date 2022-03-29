import Foundation
import ArgumentParser

/// The subcommand for updating the default templates repository.
struct TemplatesUpdateCommand: ParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "update",
    abstract: "Update the default templates to the latest version.")
  
  func run() throws {
    try Templater.updateTemplates().unwrap()
  }
}
