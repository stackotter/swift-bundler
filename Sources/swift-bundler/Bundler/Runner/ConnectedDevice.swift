/// A connected device or simulator.
struct ConnectedDevice: Equatable {
  let platform: NonMacApplePlatform
  let name: String
  let id: String
  let status: Status

  enum Status: Equatable, CustomStringConvertible {
    case available
    case summonable
    case unavailable(message: String)

    var description: String {
      switch self {
        case .available:
          return "available"
        case .summonable:
          return "summonable"
        case .unavailable(let message):
          return "unavailable: \(message)"
      }
    }
  }
}
