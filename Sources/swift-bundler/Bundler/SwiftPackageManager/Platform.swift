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

  /// Gets the platform as an ``ApplePlatform`` if it is in fact an Apple
  /// platform.
  var asApplePlatform: ApplePlatform? {
    switch self {
      case .macOS: return .macOS
      case .iOS: return .iOS
      case .iOSSimulator: return .iOSSimulator
      case .visionOS: return .visionOS
      case .visionOSSimulator: return .visionOSSimulator
      case .tvOS: return .tvOS
      case .tvOSSimulator: return .tvOSSimulator
      case .linux: return nil
    }
  }

  /// Gets whether the platform is an Apple platform (e.g. iOS) or not.
  var isApplePlatform: Bool {
    asApplePlatform != nil
  }

  /// The platform's os (e.g. ``Platform/iOS`` and ``Platform/iOSSimulator``
  /// are both ``OS/iOS``).
  var os: OS {
    switch self {
      case .macOS: return .macOS
      case .iOS, .iOSSimulator: return .iOS
      case .visionOS, .visionOSSimulator: return .visionOS
      case .tvOS, .tvOSSimulator: return .tvOS
      case .linux: return .linux
    }
  }

  /// A simple lossless conversion.
  init(_ applePlatform: ApplePlatform) {
    switch applePlatform {
      case .macOS: self = .macOS
      case .iOS: self = .iOS
      case .iOSSimulator: self = .iOSSimulator
      case .visionOS: self = .visionOS
      case .visionOSSimulator: self = .visionOSSimulator
      case .tvOS: self = .tvOS
      case .tvOSSimulator: self = .tvOSSimulator
    }
  }

  /// The platform that Swift Bundler is currently being run on.
  static var host: Platform {
    HostPlatform.hostPlatform.platform
  }
}

extension Platform: Equatable {
  public static func == (lhs: Platform, rhs: AppleSDKPlatform) -> Bool {
    lhs == rhs.platform
  }
}
