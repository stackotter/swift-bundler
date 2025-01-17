/// A supported Swift Bundler host platform.
enum HostPlatform {
  case macOS
  case linux

  /// The platform's reprsentation in the regular ``Platform`` enum.
  var platform: Platform {
    switch self {
      case .macOS:
        return .macOS
      case .linux:
        return .linux
    }
  }

  /// The platform that Swift Bundler is currently running on.
  static var hostPlatform: Self {
    #if os(macOS)
      return .macOS
    #elseif os(Linux)
      return .linux
    #endif
  }
}
