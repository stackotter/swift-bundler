import Foundation
import ArgumentParser

/// The subcommand for managing and listing available package templates.
struct TemplatesCommand: ParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "templates",
    abstract: "Manage and list available package templates.",
    subcommands: [
      TemplatesListCommand.self,
      TemplatesInfoCommand.self,
      TemplatesUpdateCommand.self
    ],
		defaultSubcommand: TemplatesListCommand.self)
}
