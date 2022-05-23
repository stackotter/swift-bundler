import Foundation
import ArgumentParser

/// The subcommand for listing available simulators.
struct SimulatorsListCommand: Command {
  static var configuration = CommandConfiguration(
    commandName: "list",
    abstract: "List available iOS simulators."
  )

  /// A search term or terms to filter by.
  @Argument(
    help: "A search term to filter simulators with.")
  var filter: String?

  func wrappedRun() throws {
    let simulators = try SimulatorManager.listAvailableSimulators(searchTerm: filter).unwrap()

    Output {
      Section("Simulators") {
        KeyedList {
          for simulator in simulators {
            KeyedList.Entry(simulator.id, simulator.name)
          }
        }
      }
      Section("Booting a simulator") {
        ExampleCommand("swift bundler simulators boot [id]")
      }
    }.show()
  }
}
