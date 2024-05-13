import Foundation

/// A SwiftPM build plan as seen in `.build/debug.yaml` and co.
struct BuildPlan: Codable {
  var commands: [String: Command]

  struct Command: Codable {
    var tool: String
    var arguments: [String]?

    enum CodingKeys: String, CodingKey {
      case tool
      case arguments = "args"
    }
  }
}
