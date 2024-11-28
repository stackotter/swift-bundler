import Foundation

/// A device that can be used to run apps.
enum Device: Equatable, CustomStringConvertible {
  case macOS
  case iOS
  case visionOS
  case tvOS
  case linux
  case iOSSimulator(id: String)
  case visionOSSimulator(id: String)
  case tvOSSimulator(id: String)

  var description: String {
    switch self {
      case .macOS:
        return "macOS host machine"
      case .linux:
        return "Linux host machine"
      case .iOS:
        return "iOS device"
      case .visionOS:
        return "visionOS device"
      case .tvOS:
        return "Apple TV"
      case .iOSSimulator(let id):
        return "iOS simulator (id: \(id))"
      case .visionOSSimulator(let id):
        return "visionOS simulator (id: \(id))"
      case .tvOSSimulator(let id):
        return "tvOS simulator (id: \(id))"
    }
  }
}
