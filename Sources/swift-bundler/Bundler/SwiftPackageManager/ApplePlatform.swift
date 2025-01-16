import Foundation

/// An Apple platform to build for.
enum ApplePlatform: String, CaseIterable {
  case macOS
  case iOS
  case iOSSimulator
  case visionOS
  case visionOSSimulator
  case tvOS
  case tvOSSimulator

  /// The platform's os (e.g. ``ApplePlatform/iOS`` and ``ApplePlatform/iOSSimulator``
  /// are both ``AppleOS/iOS``).
  var os: AppleOS {
    switch self {
      case .macOS: return .macOS
      case .iOS, .iOSSimulator: return .iOS
      case .visionOS, .visionOSSimulator: return .visionOS
      case .tvOS, .tvOSSimulator: return .tvOS
    }
  }

  /// The underlying platform.
  var platform: Platform {
    switch self {
      case .macOS:
        return .macOS
      case .iOS:
        return .iOS
      case .iOSSimulator:
        return .iOSSimulator
      case .visionOS:
        return .visionOS
      case .visionOSSimulator:
        return .visionOSSimulator
      case .tvOS:
        return .tvOS
      case .tvOSSimulator:
        return .tvOSSimulator
    }
  }

  /// The name of this platform when used in Xcode build destinations.
  var xcodeDestinationName: String {
    switch self {
      case .macOS:
        return "macOS"
      case .iOS:
        return "iOS"
      case .iOSSimulator:
        return "iOS Simulator"
      case .tvOS:
        return "tvOS"
      case .tvOSSimulator:
        return "tvOS Simulator"
      case .visionOS:
        return "visionOS"
      case .visionOSSimulator:
        return "visionOS Simulator"
    }
  }
}
