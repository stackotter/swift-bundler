import Foundation

/// An OS to build for.
enum OS: String, CaseIterable {
  case macOS
  case iOS
  case visionOS
  case tvOS
  case linux

  /// The display name of the os.
  var name: String {
    switch self {
      case .macOS, .iOS, .visionOS, .tvOS:
        return rawValue
      case .linux:
        return "Linux"
    }
  }
}
