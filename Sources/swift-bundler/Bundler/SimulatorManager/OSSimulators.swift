import Foundation

/// A list of simulators, per OS, as parsed from the `simctl` command-line tool.
struct OSSimulator {
  var OS: String
  var simulators: [Simulator] = []
}
