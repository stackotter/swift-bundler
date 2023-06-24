import Foundation

/// A platform to build for.
enum Platform: String, CaseIterable {
  case macOS
  case iOS
  case iOSSimulator
  case linux

  /// The platform's name.
  var name: String {
    return rawValue
  }

  /// The platform's sdk name (e.g. for `iOS` it's `iphoneos`).
  var sdkName: String {
    switch self {
      case .macOS:
        return "macosx"
      case .iOS:
        return "iphoneos"
      case .iOSSimulator:
        return "iphonesimulator"
      case .linux:
        return "linux"
    }
  }

  /// Whether the platform is a simulator or not.
  var isSimulator: Bool {
    switch self {
      case .iOSSimulator:
        return true
      case .macOS, .iOS, .linux:
        return false
    }
  }

  /// The platform's name in a SwiftPM manifest's JSON representation.
  var manifestName: String {
    switch self {
      case .macOS, .iOS, .linux:
        return name.lowercased()
      case .iOSSimulator:
        return Platform.iOS.name.lowercased()
    }
  }

  /// The platform that Swift Bundler is currently being run on.
  static var currentPlatform: Platform {
    #if os(macOS)
      return .macOS
    #elseif os(Linux)
      return .linux
    #endif
  }
}
