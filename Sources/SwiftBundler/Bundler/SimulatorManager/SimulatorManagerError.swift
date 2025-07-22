import Foundation
import ErrorKit

/// An error returned by ``SimulatorManager``.
enum SimulatorManagerError: Throwable {
  case failedToRunSimCTL(Process.Error)
  case failedToDecodeJSON(Error)
  case failedToOpenSimulator(Process.Error)

  var userFriendlyMessage: String {
    switch self {
      case .failedToRunSimCTL(let error):
        return "Failed to run simctl: \(error.localizedDescription)"
      case .failedToDecodeJSON:
        return "Failed to decode JSON returned by simctl"
      case .failedToOpenSimulator(let error):
        return "Failed to open simulator: \(error.localizedDescription)"
    }
  }
}
