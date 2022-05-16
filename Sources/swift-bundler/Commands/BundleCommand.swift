import Foundation
import ArgumentParser

/// The subcommand for creating app bundles for a package.
struct BundleCommand: AsyncCommand {
  static var configuration = CommandConfiguration(
    commandName: "bundle",
    abstract: "Create an app bundle from a package.")

  /// The name of the app to build.
  @Argument(
    help: "The name of the app to build.")
  var appName: String?

  /// The directory containing the package to build.
  @Option(
    name: [.customShort("d"), .customLong("directory")],
    help: "The directory containing the package to build.",
    transform: URL.init(fileURLWithPath:))
  var packageDirectory: URL?

  /// The directory to output the bundled .app to.
  @Option(
    name: .shortAndLong,
    help: "The directory to output the bundled .app to.",
    transform: URL.init(fileURLWithPath:))
  var outputDirectory: URL?

  /// The directory containing the built products. Can only be set when `--skip-build` is supplied.
  @Option(
    name: .long,
    help: "The directory containing the built products. Can only be set when `--skip-build` is supplied.",
    transform: URL.init(fileURLWithPath:))
  var productsDirectory: URL?

  /// The build configuration to use.
  @Option(
    name: [.customShort("c"), .customLong("configuration")],
    help: "The build configuration to use \(BuildConfiguration.possibleValuesString).",
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
      let possibleValues = BuildArchitecture.possibleValuesString
      let defaultValue = BuildArchitecture.current.rawValue
      return "The architectures to build for \(possibleValues). (default: [\(defaultValue)])"
    }(),
    transform: {
      guard let arch = BuildArchitecture.init(rawValue: $0) else {
        throw CLIError.invalidArchitecture($0)
      }
      return arch
    })
  var architectures: [BuildArchitecture] = []

  /// The platform to build for (incompatible with `--arch`).
  @Option(
    name: .shortAndLong,
    help: {
      return "The platform to build for (macOS|iOS). Incompatible with `--arch`."
    }())
  var platform: String = "macOS"

  /// A codesigning identity to use.
  @Option(
    name: .customLong("identity"),
    help: "The identity to use for codesigning")
  var identity: String?

  /// A provisioing profile to use.
  @Option(
    name: .customLong("provisioning-profile"),
    help: "The provisioning profile to embed in the app (only applicable to iOS).",
    transform: URL.init(fileURLWithPath:))
  var provisioningProfile: URL?

  /// If `true`, the application will be codesigned.
  @Flag(
    name: .customLong("codesign"),
    help: "Codesign the application (use `--identity` to select the identity).")
  var shouldCodesign = false

  /// If `true` a universal application will be created (arm64 and x86_64).
  @Flag(
    name: .shortAndLong,
    help: "Build a universal application. Equivalent to '--arch arm64 --arch x86_64'.")
  var universal = false

  /// Whether to skip the build step or not.
  @Flag(
    name: .long,
    help: "Skip the build step.")
  var skipBuild = false

  /// If `true`, treat the products in the products directory as if they were built by Xcode (which is the same as universal builds by SwiftPM).
  ///
  /// Can only be `true` when ``skipBuild`` is `true`.
  @Flag(
    name: .long,
    help: .init(
      stringLiteral:
        "Treats the products in the products directory as if they were built by Xcode (which is the same as universal builds by SwiftPM)." +
        " Can only be set when `--skip-build` is supplied."
    ))
  var builtWithXcode = false

  func validateParameters(platform: Platform) -> Bool {
    // Validate parameters
    if !skipBuild {
      guard productsDirectory == nil, !builtWithXcode else {
        log.error("'--products-directory' and '--built-with-xcode' are only compatible with '--skip-build'")
        return false
      }
    }

    if case .iOS = platform, builtWithXcode || universal || !architectures.isEmpty {
      log.error("'--built-with-xcode', '--universal' and '--arch' are not compatible with '--platform iOS'")
      return false
    }

    if shouldCodesign && identity == nil {
      log.error("Please provide a codesigning identity with `--identity`")
      print(Output {
        ""
        Section("Tip: Listing available identities") {
          ExampleCommand("swift bundler list-identities")
        }
      })
      return false
    }

    if identity != nil && !shouldCodesign {
      log.error("`--identity` can only be used with `--codesign`")
      return false
    }

    if case .iOS = platform, !shouldCodesign || identity == nil || provisioningProfile == nil {
      log.error("Must specify `--identity`, `--codesign` and `--provisioning-profile` when building iOS app")
      if identity == nil {
        print(Output {
          ""
          Section("Tip: Listing available identities") {
            ExampleCommand("swift bundler list-identities")
          }
        })
      }
      return false
    }

    switch platform {
      case .iOS:
        break
      default:
        if provisioningProfile != nil {
          log.error("`--provisioning-profile` is only available when building iOS apps")
          return false
        }
    }

    return true
  }

  func getArchitectures(platform: Platform) -> [BuildArchitecture] {
    let architectures: [BuildArchitecture]
    switch platform {
      case .macOS:
        architectures = universal
          ? [.arm64, .x86_64]
          : (!self.architectures.isEmpty ? self.architectures : [BuildArchitecture.current])
      case .iOS:
        architectures = [.arm64]
    }

    return architectures
  }

  func wrappedRun() async throws {
    var appBundle: URL?

    // Start timing
    let elapsed = try await Stopwatch.time {
      // Load configuration
      let packageDirectory = packageDirectory ?? URL(fileURLWithPath: ".")
      let (appName, appConfiguration) = try Self.getAppConfiguration(
        appName,
        packageDirectory: packageDirectory
      ).unwrap()

      let platform = try Self.parsePlatform(platform, appConfiguration: appConfiguration)

      if !validateParameters(platform: platform) {
        Foundation.exit(1)
      }

      // Get relevant configuration
      let universal = universal || architectures.count > 1
      let architectures = getArchitectures(platform: platform)

      let outputDirectory = Self.getOutputDirectory(outputDirectory, packageDirectory: packageDirectory)

      appBundle = outputDirectory.appendingPathComponent("\(appName).app")

      // Get build output directory
      let productsDirectory = try productsDirectory ?? SwiftPackageManager.getProductsDirectory(
        in: packageDirectory,
        configuration: buildConfiguration,
        architectures: architectures,
        platform: platform
      ).unwrap()

      // Create build job
      let build: () async -> Result<Void, Error> = {
        SwiftPackageManager.build(
          product: appConfiguration.product,
          packageDirectory: packageDirectory,
          configuration: buildConfiguration,
          architectures: architectures,
          platform: platform
        ).mapError { error in
          return error
        }
      }

      // Create bundle job
      let bundler = getBundler(for: platform)
      let bundle = {
        await bundler.bundle(
          appName: appName,
          appConfiguration: appConfiguration,
          packageDirectory: packageDirectory,
          productsDirectory: productsDirectory,
          outputDirectory: outputDirectory,
          isXcodeBuild: builtWithXcode,
          universal: universal,
          codesigningIdentity: identity,
          provisioningProfile: provisioningProfile,
          platformVersion: platform.version
        )
      }

      // Build pipeline
      let task: () async -> Result<Void, Error>
      if skipBuild {
        task = bundle
      } else {
        task = flatten(
          build,
          bundle
        )
      }

      // Run pipeline
      try await task().unwrap()
    }

    // Output the time elapsed and app bundle location
    log.info("Done in \(elapsed.secondsString). App bundle located at '\(appBundle?.relativePath ?? "unknown")'")
  }

  /// Gets the configuration for the specified app.
  ///
  /// If no app is specified, the first app is used (unless there are multiple apps, in which case a failure is returned).
  /// - Parameters:
  ///   - appName: The app's name.
  ///   - packageDirectory: The package's root directory.
  /// - Returns: The app's configuration if successful.
  static func getAppConfiguration(
    _ appName: String?,
    packageDirectory: URL
  ) -> Result<(name: String, app: AppConfiguration), PackageConfigurationError> {
    return PackageConfiguration.load(fromDirectory: packageDirectory)
      .flatMap { configuration in
        configuration.getAppConfiguration(appName)
      }
  }

  /// Unwraps an optional output directory and returns the default output directory if it's `nil`.
  /// - Parameters:
  ///   - outputDirectory: The output directory. Returned as-is if not `nil`.
  ///   - packageDirectory: The root directory of the package.
  /// - Returns: The output directory to use.
  static func getOutputDirectory(_ outputDirectory: URL?, packageDirectory: URL) -> URL {
    return outputDirectory ?? packageDirectory.appendingPathComponent(".build/bundler")
  }

  /// Parses the platform argument in combination with the app's configuration.
  ///
  /// The app's configuration is required to populate the iOS platform's version if chosen.
  /// - Parameters:
  ///   - platform: The platform string (macOS|iOS).
  ///   - appConfiguration: The app's configuration.
  /// - Returns: The parsed platform.
  /// - Throws: ``CLIError/missingMinimumIOSVersion`` if `platform` is iOS and the app's configuration doesn't contain a minimum iOS version.
  static func parsePlatform(_ platform: String, appConfiguration: AppConfiguration) throws -> Platform {
    switch platform {
    case "macOS":
      guard let macOSVersion = appConfiguration.minimumMacOSVersion else {
        throw CLIError.missingMinimumMacOSVersion
      }
      return .macOS(version: macOSVersion)
    case "iOS":
      guard let iOSVersion = appConfiguration.minimumIOSVersion else {
        throw CLIError.missingMinimumIOSVersion
      }
      return .iOS(version: iOSVersion)
    default:
      throw CLIError.invalidPlatform(platform)
    }
  }
}
