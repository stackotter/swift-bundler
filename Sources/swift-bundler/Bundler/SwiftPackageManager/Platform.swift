import Foundation

/// A platform to build for.
enum Platform: String, CaseIterable {
  case macOS
  case iOS
  case iOSSimulator
  case visionOS
  case visionOSSimulator
  case tvOS
  case tvOSSimulator
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
      case .visionOS:
        return "xros"
      case .visionOSSimulator:
        return "xrsimulator"
      case .tvOS:
        return "appletvos"
      case .tvOSSimulator:
        return "appletvsimulator"
      case .linux:
        return "linux"
    }
  }

  /// Whether the platform is a simulator or not.
  var isSimulator: Bool {
    switch self {
      case .iOSSimulator, .visionOSSimulator, .tvOSSimulator:
        return true
      case .macOS, .iOS, .visionOS, .tvOS, .linux:
        return false
    }
  }

  /// The platform's name in a SwiftPM manifest's JSON representation.
  var manifestName: String {
    switch self {
      case .macOS, .iOS, .visionOS, .tvOS, .linux:
        return name.lowercased()
      case .iOSSimulator:
        return Platform.iOS.name.lowercased()
      case .visionOSSimulator:
        return Platform.visionOS.name.lowercased()
      case .tvOSSimulator:
        return Platform.tvOS.name.lowercased()
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
    return rawValue
  }

  /// The Apple SDK's platform name (e.g. for `iphoneos` it's `iOS`).
  var platform: Platform {
    switch self {
      case .macosx:
        return .macOS
      case .iphoneos:
        return .iOS
      case .iphonesimulator:
        return .iOSSimulator
      case .xros:
        return .visionOS
      case .xrsimulator:
        return .visionOSSimulator
      case .appletvos:
        return .tvOS
      case .appletvsimulator:
        return .tvOSSimulator
      case .linux:
        return .linux
    }
  }
}

extension Platform: Equatable
{
  public static func == (lhs: Platform, rhs: AppleSDKPlatform) -> Bool
  {
    lhs.rawValue == rhs.rawValue
  }
}
