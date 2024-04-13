import Foundation

/// A device that can be used to run apps.
enum Device: Equatable {
  case macOS
  case iOS
  case visionOS
  case tvOS
  case linux
  case iOSSimulator(id: String)
  case visionOSSimulator(id: String)
  case tvOSSimulator(id: String)
}
