import Foundation
import ErrorKit

extension SimulatorManager {
  typealias Error = RichError<ErrorMessage>

  /// An error message related to ``SimulatorManager``.
  enum ErrorMessage: Throwable {
    case failedToRunSimCTL
    case failedToDecodeJSON
    case failedToOpenSimulator

    var userFriendlyMessage: String {
      switch self {
        case .failedToRunSimCTL:
          return "Failed to run simctl"
        case .failedToDecodeJSON:
          return "Failed to decode JSON returned by simctl"
        case .failedToOpenSimulator:
          return "Failed to open simulator"
      }
    }
  }
}
