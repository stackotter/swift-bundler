import ArgumentParser
import Foundation

/// The subcommand for listing available devices.
struct DevicesListCommand: Command {
  static var configuration = CommandConfiguration(
    commandName: "list",
    abstract: "List available iOS, tvOS and visionOS devices."
  )

  func wrappedRun() async throws {
    let devices = try await DeviceManager.listDestinations().unwrap()
      .filter { device in
        !device.platform.isSimulator
      }
      .compactMap { device -> ConnectedDevice? in
        switch device {
          case .host:
            return nil
          case .connected(let device):
            return device
        }
      }

    Output {
      Section("Devices") {
        KeyedList {
          for device in devices {
            KeyedList.Entry(device.id, "\(device.name) (\(device.status))")
          }
        }
      }
    }.show()
  }
}
