/// A choice of bundler. Used by user's selecting a bundler at the command line.
enum BundlerChoice: String, CaseIterable {
  case darwinApp
  case linuxGeneric
  case linuxAppImage
  case linuxRPM
  case windowsGeneric

  /// The bundler this choice corresponds to.
  var bundler: any Bundler.Type {
    switch self {
      case .darwinApp:
        return DarwinBundler.self
      case .linuxGeneric:
        return GenericLinuxBundler.self
      case .linuxAppImage:
        return AppImageBundler.self
      case .linuxRPM:
        return RPMBundler.self
      case .windowsGeneric:
        return GenericWindowsBundler.self
    }
  }

  /// Whether the choice is supported on the host platform.
  var isSupportedOnHostPlatform: Bool {
    supportedHostPlatforms.contains(Platform.host)
  }

  /// The default choice for the host platform.
  static var defaultForHostPlatform: Self {
    // TODO: Give Platform.host its own type so that we don't have to pretend
    //   that iOS is a valid host platform (for now...)
    switch Platform.host {
      case .macOS, .iOS, .iOSSimulator, .tvOS, .tvOSSimulator, .visionOS, .visionOSSimulator:
        return .darwinApp
      case .linux:
        return .linuxGeneric
      case .windows:
        return .windowsGeneric
    }
  }

  /// A list of supported values for human consumption.
  static var supportedHostValuesDescription: String {
    let supportedChoices = allCases.filter { choice in
      choice.isSupportedOnHostPlatform
    }
    return "(\(supportedChoices.map(\.rawValue).joined(separator: "|")))"
  }

  /// Target platforms that the choice is valid for.
  var supportedTargetPlatforms: [Platform] {
    switch self {
      case .darwinApp:
        return [
          .macOS,
          .iOS, .iOSSimulator,
          .tvOS, .tvOSSimulator,
          .visionOS, .visionOSSimulator,
        ]
      case .linuxGeneric, .linuxAppImage, .linuxRPM:
        return [.linux]
      case .windowsGeneric:
        return [.windows]
    }
  }

  /// Host platforms that the choice is valid for.
  var supportedHostPlatforms: [Platform] {
    // Nice and simple one-to-one for now. With SwiftPM cross-compilation advancing
    // I'm sure I'll eventually get cross-bundling working.
    supportedTargetPlatforms
  }
}
