import Foundation

/// An apple SDK platform name to build for.
enum AppleSDKPlatform: String, CaseIterable {
  case macosx
  case iphoneos
  case iphonesimulator
  case xros
  case xrsimulator
  case appletvos
  case appletvsimulator
  case linux

  /// The platform's name.
  var name: String {
    rawValue
  }

  /// The Apple SDK's platform name (e.g. for `iphoneos` it's `iOS`).
  var platform: Platform {
    switch self {
      case .macosx:
        .macOS
      case .iphoneos:
        .iOS
      case .iphonesimulator:
        .iOSSimulator
      case .xros:
        .visionOS
      case .xrsimulator:
        .visionOSSimulator
      case .appletvos:
        .tvOS
      case .appletvsimulator:
        .tvOSSimulator
      case .linux:
        .linux
    }
  }
}
