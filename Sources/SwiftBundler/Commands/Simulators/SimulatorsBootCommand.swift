import ArgumentParser
import Foundation

/// The subcommand for booting simulators.
struct SimulatorsBootCommand: Command {
  static var configuration = CommandConfiguration(
    commandName: "boot",
    abstract: "Boot an iOS or visionOS simulator."
  )

  /// The id or name of the simulator to start.
  @Argument(
    help: "The id or name of the simulator to start.")
  var idOrName: String

  func wrappedRun() async throws {
    log.info("Booting '\(idOrName)'")
    try await SimulatorManager.bootSimulator(id: idOrName).unwrap()
    log.info("Opening 'Simulator.app'")
    try await SimulatorManager.openSimulatorApp().unwrap()
  }
}
