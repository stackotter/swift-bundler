import Foundation

/// An error returned by ``SimulatorManager``.
enum SimulatorManagerError: LocalizedError {
  case failedToRunSimCTL(ProcessError)
  case failedToDecodeJSON(Error)
  case failedToOpenSimulator(ProcessError)

  var errorDescription: String? {
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
