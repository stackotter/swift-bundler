/// A choice of bundler. Used by user's selecting a bundler at the command line.
enum BundlerChoice: String, CaseIterable {
  case darwinApp
  case linuxGeneric
  case linuxAppImage
  case linuxRPM
  case windowsGeneric
  case windowsMSI

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
      case .windowsMSI:
        return MSIBundler.self
    }
  }

  /// Whether the choice is supported on the host platform.
  var isSupportedOnHostPlatform: Bool {
    supportedHostPlatforms.contains(HostPlatform.hostPlatform)
  }

  /// The default choice for the host platform.
  static var defaultForHostPlatform: Self {
    switch HostPlatform.hostPlatform {
      case .macOS:
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
          .macOS, .macCatalyst,
          .iOS, .iOSSimulator,
          .tvOS, .tvOSSimulator,
          .visionOS, .visionOSSimulator,
        ]
      case .linuxGeneric, .linuxAppImage, .linuxRPM:
        return [.linux]
      case .windowsGeneric, .windowsMSI:
        return [.windows]
    }
  }

  /// Host platforms that the choice is valid for.
  var supportedHostPlatforms: [HostPlatform] {
    switch self {
      case .darwinApp:
        return [.macOS]
      case .linuxGeneric, .linuxAppImage, .linuxRPM:
        return [.linux]
      case .windowsGeneric, .windowsMSI:
        return [.windows]
    }
  }
}
