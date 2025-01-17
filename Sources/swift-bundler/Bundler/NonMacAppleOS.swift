/// A non-macOS Apple operating system.
enum NonMacAppleOS: CaseIterable {
  case iOS
  case tvOS
  case visionOS

  /// The prefix that simulator runtimes matching this operating system will
  /// have.
  var simulatorRuntimePrefix: String {
    let osString: String
    switch self {
      case .iOS:
        osString = "iOS"
      case .tvOS:
        osString = "tvOS"
      case .visionOS:
        osString = "xrOS"
    }
    return "com.apple.CoreSimulator.SimRuntime.\(osString)-"
  }

  /// The simulator platform corresponding to this OS.
  var simulatorPlatform: NonMacApplePlatform {
    .simulator(self)
  }

  /// The physical device platform corresponding to this OS.
  var physicalPlatform: NonMacApplePlatform {
    .physical(self)
  }
}
