import Foundation
import StackOtterArgParser

struct BundleArguments: ParsableArguments {
  /// The name of the app to build.
  @Argument(
    help: "The name of the app to build.")
  var appName: String?

  @Option(
    help: "The bundler to use \(BundlerChoice.possibleValuesDescription).",
    transform: {
      guard let choice = BundlerChoice(rawValue: $0) else {
        throw CLIError.invalidBundlerChoice($0)
      }
      return choice
    })
  var bundler = BundlerChoice.defaultForHostPlatform

  /// The directory containing the package to build.
  @Option(
    name: [.customShort("d"), .customLong("directory")],
    help:
      """
      The directory containing the package to build. This changes the working \
      directory before any other operation
      """,
    transform: URL.init(fileURLWithPath:))
  var packageDirectory: URL?

  /// Overrides the default configuration file location.
  @Option(
    name: [.customLong("config-file")],
    help: "Overrides the default configuration file location",
    transform: URL.init(fileURLWithPath:))
  var configurationFileOverride: URL?

  /// The directory to output the bundled .app to.
  @Option(
    name: .shortAndLong,
    help: "The directory to output the bundled .app to.",
    transform: URL.init(fileURLWithPath:))
  var outputDirectory: URL?

  /// The directory containing the built products. Can only be set when
  /// `--skip-build` is supplied.
  @Option(
    name: .long,
    help:
      """
      The directory containing the built products. Can only be set when \
      `--skip-build` is supplied.
      """,
    transform: URL.init(fileURLWithPath:))
  var productsDirectory: URL?

  /// The build configuration to use.
  @Option(
    name: [.customShort("c"), .customLong("configuration")],
    help: "The build configuration to use \(BuildConfiguration.possibleValuesDescription).",
    transform: {
      guard let configuration = BuildConfiguration.init(rawValue: $0.lowercased()) else {
        throw CLIError.invalidBuildConfiguration($0)
      }
      return configuration
    })
  var buildConfiguration = BuildConfiguration.debug

  /// The architectures to build for.
  @Option(
    name: [.customShort("a"), .customLong("arch")],
    parsing: .singleValue,
    help: {
      let possibleValues = BuildArchitecture.possibleValuesDescription
      let defaultValue = BuildArchitecture.current.rawValue
      return "The architectures to build for \(possibleValues). (default: [\(defaultValue)])"
    }(),
    transform: { string in
      guard let arch = BuildArchitecture.init(rawValue: string) else {
        throw CLIError.invalidArchitecture(string)
      }
      return arch
    })
  var architectures: [BuildArchitecture] = []

  /// A custom scratch directory to use. Defaults to `.build`.
  @Option(
    name: .customLong("scratch-path"),
    help: "A custom scratch directory path (default: .build)",
    transform: URL.init(fileURLWithPath:))
  var scratchDirectory: URL?

  /// Additional arguments to pass to SwiftPM when building.
  @Option(
    name: .customLong("Xswiftpm"),
    parsing: .unconditionalSingleValue,
    help: "Additional arguments to pass to SwiftPM when building.")
  var additionalSwiftPMArguments: [String] = []

  /// The platform to build for.
  @Option(
    name: .shortAndLong,
    help: {
      let possibleValues = Platform.possibleValuesDescription
      return "The platform to build for \(possibleValues). (default: macOS)"
    }(),
    transform: { string in
      // also support getting a platform by its apple sdk equivalent.
      if let appleSDK = AppleSDKPlatform(rawValue: string) {
        return appleSDK.platform
      }

      guard let platform = Platform(rawValue: string) else {
        throw CLIError.invalidPlatform(string)
      }
      return platform
    })
  var platform = Platform.host

  /// A codesigning identity to use.
  @Option(
    name: .customLong("identity"),
    help: "The identity to use for codesigning")
  var identity: String?

  /// A provisioning profile to use.
  #if os(macOS)
    @Option(
      name: .customLong("provisioning-profile"),
      help: "The provisioning profile to embed in the app (only applicable to visionOS and iOS).",
      transform: URL.init(fileURLWithPath:))
  #endif
  var provisioningProfile: URL?

  /// If `true`, the application will be codesigned.
  #if os(macOS)
    @Flag(
      name: .customLong("codesign"),
      help: "Codesign the application (use `--identity` to select the identity).")
  #endif
  var shouldCodesign = false

  /// A codesigning entitlements file to use.
  #if os(macOS)
    @Option(
      name: .customLong("entitlements"),
      help: "The entitlements file to use for codesigning",
      transform: URL.init(fileURLWithPath:))
  #endif
  var entitlements: URL?

  /// If `true`, a universal application will be created (arm64 and x86_64).
  #if os(macOS)
    @Flag(
      name: .shortAndLong,
      help: "Build a universal application. Equivalent to '--arch arm64 --arch x86_64'.")
  #endif
  var universal = false

  /// If `true`, a stand-alone application will be created (which doesn't depend on any third-party
  /// system-wide dynamic libraries being installed such as gtk).
  #if os(macOS)
    @Flag(
      name: .customLong("experimental-stand-alone"),
      help:
        "Build an application which doesn't rely on any system-wide third-party libraries being installed (such as gtk). This features is experimental and potentially incompatible with '--universal', use with care."
    )
  #endif
  var standAlone = false

  /// Builds with xcodebuild instead of swiftpm.
  #if os(macOS)
    @Flag(
      name: .customLong("xcodebuild"),
      help: "Builds with xcodebuild instead of swiftpm."
    )
  #endif
  var xcodebuild = false

  /// Builds without xcodebuild, to override embedded
  /// darwin platforms which automatically force xcodebuild,
  /// to build with swiftpm instead.
  #if os(macOS)
    @Flag(
      name: .customLong("no-xcodebuild"),
      help: "Builds without xcodebuild, to override embedded darwin platforms which automatically force xcodebuild, to build with swiftpm instead."
    )
  #endif
  var noXcodebuild = false
}
