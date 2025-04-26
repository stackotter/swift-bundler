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
  case windows

  /// The platform's display name.
  var displayName: String {
    switch self {
      case .macOS:
        return "macOS"
      case .iOS:
        return "iOS"
      case .iOSSimulator:
        return "iOS Simulator"
      case .visionOS:
        return "visionOS"
      case .visionOSSimulator:
        return "visionOS Simulator"
      case .tvOS:
        return "tvOS"
      case .tvOSSimulator:
        return "tvOS Simulator"
      case .linux:
        return "Linux"
      case .windows:
        return "Windows"
    }
  }

  /// The platform's name.
  var name: String {
    return rawValue
  }

  // TODO: Move this to `ApplePlatform` and refactor usages accordingly
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
      case .windows:
        return "windows"
    }
  }

  /// Whether the platform is a simulator or not.
  var isSimulator: Bool {
    switch self {
      case .iOSSimulator, .visionOSSimulator, .tvOSSimulator:
        return true
      case .macOS, .iOS, .visionOS, .tvOS, .linux, .windows:
        return false
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
      case .linux, .windows: return nil
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
      case .windows: return .windows
    }
  }

  /// The platform's executable file extension if any.
  var executableFileExtension: String? {
    switch self {
      case .windows:
        return "exe"
      case .macOS, .linux, .iOS, .iOSSimulator,
        .tvOS, .tvOSSimulator, .visionOS, .visionOSSimulator:
        return nil
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
