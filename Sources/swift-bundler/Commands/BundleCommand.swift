import Foundation
import StackOtterArgParser

/// The subcommand for creating app bundles for a package.
struct BundleCommand: AsyncCommand {
  static var configuration = CommandConfiguration(
    commandName: "bundle",
    abstract: "Create an app bundle from a package."
  )

  /// Arguments in common with the run command.
  @OptionGroup
  var arguments: BundleArguments

  /// Whether to skip the build step or not.
  @Flag(
    name: .long,
    help: "Skip the build step.")
  var skipBuild = false

  #if os(macOS)
    /// If `true`, treat the products in the products directory as if they were built by Xcode (which is the same as universal builds by SwiftPM).
    ///
    /// Can only be `true` when ``skipBuild`` is `true`.
    @Flag(
      name: .long,
      help: .init(
        stringLiteral:
          "Treats the products in the products directory as if they were built by Xcode (which is the same as universal builds by SwiftPM)."
          + " Can only be set when `--skip-build` is supplied."
      ))
  #endif
  var builtWithXcode = false

  var hotReloadingEnabled = false

  /// Used to avoid loading configuration twice when RunCommand is used.
  static var app: (name: String, app: AppConfiguration)?  // TODO: fix this weird pattern with a better config loading system

  init() {
    _arguments = OptionGroup()
  }

  init(
    arguments: OptionGroup<BundleArguments>,
    skipBuild: Bool,
    builtWithXcode: Bool,
    hotReloadingEnabled: Bool
  ) {
    _arguments = arguments
    self.skipBuild = skipBuild
    self.builtWithXcode = builtWithXcode
    self.hotReloadingEnabled = hotReloadingEnabled
  }

  static func validateArguments(
    _ arguments: BundleArguments,
    platform: Platform,
    skipBuild: Bool,
    builtWithXcode: Bool
  ) -> Bool {
    // Validate parameters
    #if os(macOS)
      if !skipBuild {
        guard arguments.productsDirectory == nil, !builtWithXcode else {
          log.error(
            "'--products-directory' and '--built-with-xcode' are only compatible with '--skip-build'"
          )
          return false
        }
      }
    #endif

    if Platform.currentPlatform == .linux && platform != .linux {
      log.error("'--platform \(platform)' is not supported on Linux")
      return false
    }

    // macOS-only arguments
    #if os(macOS)
      if platform == .iOS || platform == .visionOS,
        builtWithXcode || arguments.universal || !arguments.architectures.isEmpty
      {
        log.error(
          "'--built-with-xcode', '--universal' and '--arch' are not compatible with '--platform \(platform.rawValue)'"
        )
        return false
      }

      if arguments.shouldCodesign && arguments.identity == nil {
        log.error("Please provide a codesigning identity with `--identity`")
        Output {
          ""
          Section("Tip: Listing available identities") {
            ExampleCommand("swift bundler list-identities")
          }
        }.show()
        return false
      }

      if arguments.identity != nil && !arguments.shouldCodesign {
        log.error("`--identity` can only be used with `--codesign`")
        return false
      }

      if platform == .iOS || platform == .visionOS || platform == .tvOS,
        !arguments.shouldCodesign || arguments.identity == nil
          || arguments.provisioningProfile == nil
      {
        log.error(
          "Must specify `--identity`, `--codesign` and `--provisioning-profile` when '--platform \(platform.rawValue)'"
        )
        if arguments.identity == nil {
          Output {
            ""
            Section("Tip: Listing available identities") {
              ExampleCommand("swift bundler list-identities")
            }
          }.show()
        }
        return false
      }

      if platform != .macOS && arguments.standAlone {
        log.error("'--experimental-stand-alone' only works on macOS")
        return false
      }

      switch platform {
        case .iOS, .visionOS, .tvOS:
          break
        default:
          if arguments.provisioningProfile != nil {
            log.error(
              "`--provisioning-profile` is only available when building visionOS and iOS apps")
            return false
          }
      }
    #endif

    return true
  }

  func getArchitectures(platform: Platform) -> [BuildArchitecture] {
    let architectures: [BuildArchitecture]
    switch platform {
      case .macOS:
        architectures =
          arguments.universal
          ? [.arm64, .x86_64]
          : (!arguments.architectures.isEmpty
            ? arguments.architectures : [BuildArchitecture.current])
      case .iOS, .visionOS, .tvOS:
        architectures = [.arm64]
      case .linux, .iOSSimulator, .visionOSSimulator, .tvOSSimulator:
        architectures = [BuildArchitecture.current]
    }

    return architectures
  }

  func wrappedRun() async throws {
    var appBundle: URL?

    // Start timing
    let elapsed = try await Stopwatch.time {
      // Load configuration
      let packageDirectory = arguments.packageDirectory ?? URL(fileURLWithPath: ".")
      let scratchDirectory =
        arguments.scratchDirectory ?? packageDirectory.appendingPathComponent(".build")

      let (appName, appConfiguration) = try Self.getAppConfiguration(
        arguments.appName,
        packageDirectory: packageDirectory,
        customFile: arguments.configurationFileOverride
      ).unwrap()

      if !Self.validateArguments(
        arguments, platform: arguments.platform, skipBuild: skipBuild,
        builtWithXcode: builtWithXcode)
      {
        Foundation.exit(1)
      }

      // Get relevant configuration
      let universal = arguments.universal || arguments.architectures.count > 1
      let architectures = getArchitectures(platform: arguments.platform)

      let outputDirectory = Self.getOutputDirectory(
        arguments.outputDirectory,
        scratchDirectory: scratchDirectory
      )

      appBundle = outputDirectory.appendingPathComponent("\(appName).app")

      // Load package manifest
      log.info("Loading package manifest")
      let manifest = try await SwiftPackageManager.loadPackageManifest(from: packageDirectory)
        .unwrap()

      guard let platformVersion = manifest.platformVersion(for: arguments.platform) else {
        let manifestFile = packageDirectory.appendingPathComponent("Package.swift")
        throw CLIError.failedToGetPlatformVersion(
          platform: arguments.platform,
          manifest: manifestFile
        )
      }

      // Get build output directory
      let productsDirectory =
        try arguments.productsDirectory
        ?? SwiftPackageManager.getProductsDirectory(
          in: packageDirectory,
          scratchDirectory: scratchDirectory,
          configuration: arguments.buildConfiguration,
          architectures: architectures,
          platform: arguments.platform,
          platformVersion: platformVersion
        ).unwrap()

      // Create build job
      let build: () async -> Result<Void, Error> = {
        SwiftPackageManager.build(
          product: appConfiguration.product,
          packageDirectory: packageDirectory,
          scratchDirectory: scratchDirectory,
          configuration: arguments.buildConfiguration,
          architectures: architectures,
          platform: arguments.platform,
          platformVersion: platformVersion,
          hotReloadingEnabled: hotReloadingEnabled
        ).mapError { error in
          return error
        }
      }

      // Create bundle job
      let bundlerContext = BundlerContext(
        appName: appName,
        packageName: manifest.displayName,
        appConfiguration: appConfiguration,
        packageDirectory: packageDirectory,
        productsDirectory: productsDirectory,
        outputDirectory: outputDirectory,
        platform: arguments.platform
      )
      let bundle = {
        if let applePlatform = arguments.platform.asApplePlatform {
          let codeSigningContext: DarwinBundler.Context.CodeSigningContext?
          if let identity = arguments.identity {
            codeSigningContext = DarwinBundler.Context.CodeSigningContext(
              identity: identity,
              entitlements: arguments.entitlements,
              provisioningProfile: arguments.provisioningProfile
            )
          } else {
            codeSigningContext = nil
          }

          return DarwinBundler.bundle(
            bundlerContext,
            DarwinBundler.Context(
              isXcodeBuild: builtWithXcode,
              universal: universal,
              standAlone: arguments.standAlone,
              platform: applePlatform,
              platformVersion: platformVersion,
              codeSigningContext: codeSigningContext
            )
          ).intoAnyError()
        } else {
          return AppImageBundler.bundle(bundlerContext, ()).intoAnyError()
        }
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
    log.info(
      "Done in \(elapsed.secondsString). App bundle located at '\(appBundle?.relativePath ?? "unknown")'"
    )
  }

  /// Gets the configuration for the specified app.
  ///
  /// If no app is specified, the first app is used (unless there are multiple apps, in which case a failure is returned).
  /// - Parameters:
  ///   - appName: The app's name.
  ///   - packageDirectory: The package's root directory.
  ///   - customFile: A custom configuration file not at the standard location.
  /// - Returns: The app's configuration if successful.
  static func getAppConfiguration(
    _ appName: String?,
    packageDirectory: URL,
    customFile: URL? = nil
  ) -> Result<(name: String, app: AppConfiguration), PackageConfigurationError> {
    if let app = Self.app {
      return .success(app)
    }

    return PackageConfiguration.load(
      fromDirectory: packageDirectory,
      customFile: customFile
    ).flatMap { configuration in
      return configuration.getAppConfiguration(appName)
    }.map { app in
      Self.app = app
      return app
    }
  }

  /// Unwraps an optional output directory and returns the default output directory if it's `nil`.
  /// - Parameters:
  ///   - outputDirectory: The output directory. Returned as-is if not `nil`.
  ///   - scratchDirectory: The configured scratch directory.
  /// - Returns: The output directory to use.
  static func getOutputDirectory(_ outputDirectory: URL?, scratchDirectory: URL) -> URL {
    return outputDirectory ?? scratchDirectory.appendingPathComponent("bundler")
  }
}
