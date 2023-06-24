import Foundation

/// A device that can be used to run apps.
enum Device {
  case macOS
  case iOS
  case linux
  case iOSSimulator(id: String)
}
