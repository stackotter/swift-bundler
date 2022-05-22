import Foundation

/// A list of simulator as parsed from the `simctl` command-line tool.
struct SimulatorList: Codable {
  /// The devices matching the query (keyed by platform).
  var devices: [String: [Simulator]]
}
