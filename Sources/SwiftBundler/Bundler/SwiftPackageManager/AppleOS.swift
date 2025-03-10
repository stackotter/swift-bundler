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
