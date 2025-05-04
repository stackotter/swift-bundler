import Foundation

/// An Apple OS to build for.
enum AppleOS: String, CaseIterable {
  case macOS
  case iOS
  case visionOS
  case tvOS

  /// The display name of the os.
  var name: String {
    return rawValue
  }

  /// The OS's name in a SwiftPM manifest's JSON representation.
  var manifestName: String {
    name.lowercased()
  }

  /// The OS's name in LLVM target triples.
  var tripleName: String {
    switch self {
      case .macOS, .iOS, .tvOS:
        return name.lowercased()
      case .visionOS:
        return "xros"
    }
  }

  /// The minimum version of this OS that Swift supports.
  var minimumSwiftSupportedVersion: String {
    switch self {
      case .macOS:
        return "10.9"
      case .iOS:
        return "7.0"
      case .visionOS:
        return "0.0"
      case .tvOS:
        return "9.0"
    }
  }

  var os: OS {
    switch self {
      case .macOS:
        return .macOS
      case .iOS:
        return .iOS
      case .visionOS:
        return .visionOS
      case .tvOS:
        return .tvOS
    }
  }
}
