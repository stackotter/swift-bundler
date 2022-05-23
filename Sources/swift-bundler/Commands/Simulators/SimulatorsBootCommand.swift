import Foundation
import ArgumentParser

/// The subcommand for booting simulators.
struct SimulatorsBootCommand: Command {
  static var configuration = CommandConfiguration(
    commandName: "boot",
    abstract: "Boot an iOS simulator."
  )

  /// The id of the simulator to start.
  @Argument(
    help: "The id of the simulator to start.")
  var id: String

  func wrappedRun() throws {
    log.info("Booting '\(id)'")
    try SimulatorManager.bootSimulator(id: id).unwrap()
    log.info("Opening 'Simulator.app'")
    try SimulatorManager.openSimulatorApp().unwrap()
  }
}
