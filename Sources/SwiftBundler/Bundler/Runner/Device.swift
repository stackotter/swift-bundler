import ArgumentParser
import Foundation

/// A device that can be used to run apps.
enum Device: Equatable, CustomStringConvertible {
  case host(HostPlatform)
  /// Mac Catalyst isn't a host platform, because we don't run Swift Bundler under
  /// Mac Catalyst, so it can't live under the `.host` case. But for all intents
  /// and purposes, this `.macCatalyst` case functions very similarly to `.host`.
  case macCatalyst
  case connected(ConnectedDevice)

  var description: String {
    switch self {
      case .host(let platform):
        return "\(platform.platform.name) host machine"
      case .macCatalyst:
        return "Mac Catalyst host machine"
      case .connected(let device):
        return "\(device.name) (\(device.platform.platform), id: \(device.id))"
    }
  }

  var id: String? {
    switch self {
      case .host, .macCatalyst:
        return nil
      case .connected(let device):
        return device.id
    }
  }

  var platform: Platform {
    switch self {
      case .host(let platform):
        return platform.platform
      case .macCatalyst:
        return .macCatalyst
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
      case .macCatalyst:
        self = .macCatalyst
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
