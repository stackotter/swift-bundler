import Foundation

struct Simulator {
  var id: String
  var name: String
  var isAvailable: Bool
  var isBooted: Bool
  var os: NonMacAppleOS

  var device: Device {
    Device(
      nonMacApplePlatform: .simulator(os),
      name: name,
      id: id,
      status: isAvailable
        ? (isBooted ? .available : .summonable)
        : .unavailable(message: "unavailable")
    )
  }
}
