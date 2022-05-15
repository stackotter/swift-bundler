import Foundation

/// A platform to build for.
enum Platform {
  case macOS(version: String)
  case iOS(version: String)

  /// The platform's version.
  var version: String {
    switch self {
    case .macOS(let version):
      return version
    case .iOS(let version):
      return version
    }
  }

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
}
