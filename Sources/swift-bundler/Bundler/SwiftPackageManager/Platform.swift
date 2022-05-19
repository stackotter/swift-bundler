import Foundation

/// A platform to build for.
enum Platform: String {
  case macOS
  case iOS

  /// The platform's name.
  var name: String {
    switch self {
      case .macOS:
        return "macOS"
      case .iOS:
        return "iOS"
    }
  }

  /// The platform's sdk name (e.g. for `iOS` it's `iphoneos`).
  var sdkName: String {
    switch self {
      case .macOS:
        return "macosx"
      case .iOS:
        return "iphoneos"
    }
  }

  /// The platform's name in a SwiftPM manifest's JSON representation.
  var manifestName: String {
    return name.lowercased()
  }
}
