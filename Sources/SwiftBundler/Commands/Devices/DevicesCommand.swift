import ArgumentParser
import Foundation

/// The subcommand for managing and listing available devices.
struct DevicesCommand: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "devices",
    abstract: "Manage and list available devices.",
    subcommands: [
      DevicesListCommand.self
    ],
    defaultSubcommand: DevicesListCommand.self
  )
}
