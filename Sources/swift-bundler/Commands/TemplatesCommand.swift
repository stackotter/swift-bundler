import Foundation
import ArgumentParser

struct TemplatesCommand: ParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "templates",
    abstract: "Manage and list available templates",
    subcommands: [TemplatesListCommand.self, TemplatesUpdateCommand.self])
}
