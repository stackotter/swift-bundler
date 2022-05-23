import Foundation
import ArgumentParser

/// The subcommand for booting simulators.
struct SimulatorsBootCommand: Command {
  static var configuration = CommandConfiguration(
    commandName: "boot",
    abstract: "Boot an iOS simulator."
  )

  /// The id or name of the simulator to start.
  @Argument(
    help: "The id or name of the simulator to start.")
  var idOrName: String

  func wrappedRun() throws {
    log.info("Booting '\(idOrName)'")
    try SimulatorManager.bootSimulator(id: idOrName).unwrap()
    log.info("Opening 'Simulator.app'")
    try SimulatorManager.openSimulatorApp().unwrap()
  }
}
