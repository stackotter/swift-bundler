import Foundation

/// A simulator as provided by the `simctl` command-line tool.
struct Simulator: Codable {
  /// The possible states a simulator can be in.
  enum State: String, Codable {
    case shutdown = "Shutdown"
    case booted = "Booted"
  }

  enum CodingKeys: String, CodingKey {
    case id = "udid"
    case dataPath
    case dataPathSize
    case logPath
    case isAvailable
    case deviceTypeIdentifier
    case state
    case name
  }

  /// The simulator's unique identifier.
  var id: String
  /// The location that the simulator stores its data.
  var dataPath: URL
  /// The amount of data the simulator has stored.
  var dataPathSize: Int
  /// The location of the log directory.
  var logPath: URL
  /// Whether the simulator is available or not.
  var isAvailable: Bool
  /// An identifier for the type of device that is being simulated (e.g. `com.apple.CoreSimulator.SimDeviceType.iPhone-8`).
  var deviceTypeIdentifier: String
  /// The device's state.
  var state: State
  /// The display name for the simulator (e.g. `iPhone 8`).
  var name: String
}
