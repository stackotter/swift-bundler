import Foundation
import StackOtterArgParser

/// The subcommand for managing and listing available simulators.
struct SimulatorsCommand: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "simulators",
    abstract: "Manage and list available simulators.",
    subcommands: [
      SimulatorsListCommand.self,
      SimulatorsBootCommand.self,
    ],
    defaultSubcommand: SimulatorsListCommand.self
  )
}
