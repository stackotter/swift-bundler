import Foundation
import ArgumentParser

/// The subcommand for creating app bundles for a package.
struct BundleCommand: AsyncCommand {
  static var configuration = CommandConfiguration(
    commandName: "bundle",
    abstract: "Create an app bundle from a package."
  )

  /// Arguments in common with the run command.
  @OptionGroup
  var arguments: BundleArguments

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

  static func validateArguments(_ arguments: BundleArguments, platform: Platform, builtWithXcode: Bool) -> Bool {
    // Validate parameters
    if !arguments.skipBuild {
      guard arguments.productsDirectory == nil, !builtWithXcode else {
        log.error("'--products-directory' and '--built-with-xcode' are only compatible with '--skip-build'")
        return false
      }
    }

    if case .iOS = platform, builtWithXcode || arguments.universal || !arguments.architectures.isEmpty {
      log.error("'--built-with-xcode', '--universal' and '--arch' are not compatible with '--platform iOS'")
      return false
    }

    if arguments.shouldCodesign && arguments.identity == nil {
      log.error("Please provide a codesigning identity with `--identity`")
      print(Output {
        ""
        Section("Tip: Listing available identities") {
          ExampleCommand("swift bundler list-identities")
        }
      })
      return false
    }

    if arguments.identity != nil && !arguments.shouldCodesign {
      log.error("`--identity` can only be used with `--codesign`")
      return false
    }

    if case .iOS = platform, !arguments.shouldCodesign || arguments.identity == nil || arguments.provisioningProfile == nil {
      log.error("Must specify `--identity`, `--codesign` and `--provisioning-profile` when building iOS app")
      if arguments.identity == nil {
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
        if arguments.provisioningProfile != nil {
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
        architectures = arguments.universal
          ? [.arm64, .x86_64]
          : (!arguments.architectures.isEmpty ? arguments.architectures : [BuildArchitecture.current])
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
      let packageDirectory = arguments.packageDirectory ?? URL(fileURLWithPath: ".")
      let (appName, appConfiguration) = try Self.getAppConfiguration(
        arguments.appName,
        packageDirectory: packageDirectory
      ).unwrap()

      let platform = try Self.parsePlatform(arguments.platform, appConfiguration: appConfiguration)

      if !Self.validateArguments(arguments, platform: platform, builtWithXcode: builtWithXcode) {
        Foundation.exit(1)
      }

      // Get relevant configuration
      let universal = arguments.universal || arguments.architectures.count > 1
      let architectures = getArchitectures(platform: platform)

      let outputDirectory = Self.getOutputDirectory(arguments.outputDirectory, packageDirectory: packageDirectory)

      appBundle = outputDirectory.appendingPathComponent("\(appName).app")

      // Get build output directory
      let productsDirectory = try arguments.productsDirectory ?? SwiftPackageManager.getProductsDirectory(
        in: packageDirectory,
        configuration: arguments.buildConfiguration,
        architectures: architectures,
        platform: platform
      ).unwrap()

      // Create build job
      let build: () async -> Result<Void, Error> = {
        SwiftPackageManager.build(
          product: appConfiguration.product,
          packageDirectory: packageDirectory,
          configuration: arguments.buildConfiguration,
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
          codesigningIdentity: arguments.identity,
          provisioningProfile: arguments.provisioningProfile,
          platformVersion: platform.version
        )
      }

      // Build pipeline
      let task: () async -> Result<Void, Error>
      if arguments.skipBuild {
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
