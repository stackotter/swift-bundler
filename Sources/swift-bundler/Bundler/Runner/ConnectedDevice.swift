/// A connected device or simulator.
struct ConnectedDevice: Equatable {
  let platform: NonMacApplePlatform
  let name: String
  let id: String
  let status: Status

  enum Status: Equatable {
    case available
    case summonable
    case unavailable(message: String)
  }
}
