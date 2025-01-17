import Foundation
import StackOtterArgParser

/// A device that can be used to run apps.
enum Device: Equatable, CustomStringConvertible {
  case host(HostPlatform)
  case connected(ConnectedDevice)

  var description: String {
    switch self {
      case .host(let platform):
        switch platform {
          case .macOS:
            return "macOS host machine"
          case .linux:
            return "Linux host machine"
        }
      case .connected(let device):
        return "\(device.name) (\(device.platform.platform), id: \(device.id))"
    }
  }

  var id: String? {
    switch self {
      case .host:
        return nil
      case .connected(let device):
        return device.id
    }
  }

  var platform: Platform {
    switch self {
      case .host(let platform):
        return platform.platform
      case .connected(let device):
        return device.platform.platform
    }
  }

  init(
    applePlatform platform: ApplePlatform,
    name: String,
    id: String,
    status: ConnectedDevice.Status
  ) {
    switch platform.partitioned {
      case .macOS:
        // We assume that we only have one macOS destination so we ignore the
        // device id.
        self = .host(.macOS)
      case .other(let nonMacPlatform):
        self.init(
          nonMacApplePlatform: nonMacPlatform,
          name: name,
          id: id,
          status: status
        )
    }
  }

  init(
    nonMacApplePlatform platform: NonMacApplePlatform,
    name: String,
    id: String,
    status: ConnectedDevice.Status
  ) {
    let device = ConnectedDevice(
      platform: platform,
      name: name,
      id: id,
      status: status
    )
    self = .connected(device)
  }
}
