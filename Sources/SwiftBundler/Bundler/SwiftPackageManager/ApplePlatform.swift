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

  enum Partitioned {
    case macOS
    case other(NonMacApplePlatform)
  }

  /// The platform represented in a structure that partitions macOS from
  /// all other Apple platforms.
  var partitioned: Partitioned {
    switch self {
      case .macOS:
        return .macOS
      case .iOS:
        return .other(.physical(.iOS))
      case .iOSSimulator:
        return .other(.simulator(.iOS))
      case .visionOS:
        return .other(.physical(.visionOS))
      case .visionOSSimulator:
        return .other(.simulator(.visionOS))
      case .tvOS:
        return .other(.physical(.tvOS))
      case .tvOSSimulator:
        return .other(.simulator(.tvOS))
    }
  }

  /// Whether the platform is a simulator or not.
  var isSimulator: Bool {
    switch self {
      case .macOS, .iOS, .visionOS, .tvOS:
        return false
      case .iOSSimulator, .visionOSSimulator, .tvOSSimulator:
        return true
    }
  }

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

  /// Whether the platform requires app bundles to contain provisioning
  /// profiles or not.
  var requiresProvisioningProfiles: Bool {
    switch self {
      case .iOS, .tvOS, .visionOS:
        return true
      case .macOS, .iOSSimulator, .tvOSSimulator, .visionOSSimulator:
        return false
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

  static func parseXcodeDestinationName(_ destinationName: String) -> Self? {
    Self.allCases.first { destination in
      destination.xcodeDestinationName == destinationName
    }
  }
}
