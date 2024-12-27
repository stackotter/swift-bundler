import Foundation
import StackOtterArgParser

/// The subcommand for creating app bundles for a package.
struct BundleCommand: ErrorHandledCommand {
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
          """
          Treats the products in the products directory as if they were built \
          by Xcode (which is the same as universal builds by SwiftPM). Can \
          only be set when `--skip-build` is supplied.
          """
      ))
  #endif
  var builtWithXcode = false

  var hotReloadingEnabled = false

  // TODO: fix this weird pattern with a better config loading system
  /// Used to avoid loading configuration twice when RunCommand is used.
  static var bundlerConfiguration:
    (
      appName: String,
      appConfiguration: AppConfiguration.Flat,
      configuration: PackageConfiguration.Flat
    )?

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
            """
            '--products-directory' and '--built-with-xcode' are only compatible \
            with '--skip-build'
            """
          )
          return false
        }
      }
    #endif

    if Platform.host == .linux && platform != .linux {
      log.error("'--platform \(platform)' is not supported on Linux")
      return false
    }

    guard arguments.bundler.isSupportedOnHostPlatform else {
      log.error(
        """
        The '\(arguments.bundler.rawValue)' bundler is not supported on the \
        current host platform. Supported values: \
        \(BundlerChoice.supportedHostValuesDescription)
        """
      )
      return false
    }

    guard arguments.bundler.supportedTargetPlatforms.contains(platform) else {
      let alternatives = BundlerChoice.allCases.filter { choice in
        choice.supportedTargetPlatforms.contains(platform)
      }
      let alternativesDescription = "(\(alternatives.map(\.rawValue).joined(separator: "|")))"
      log.error(
        """
        The '\(arguments.bundler.rawValue)' bundler doesn't support bundling \
        for '\(platform)'. Supported target platforms: \
        \(BundlerChoice.supportedHostValuesDescription). Valid alternative \
        bundlers: \(alternativesDescription)
        """
      )
      return false
    }

    // macOS-only arguments
    #if os(macOS)
      if platform == .iOS || platform == .visionOS,
        builtWithXcode || arguments.universal || !arguments.architectures.isEmpty
      {
        log.error(
          """
          '--built-with-xcode', '--universal' and '--arch' are not compatible \
          with '--platform \(platform.rawValue)'
          """
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
          """
          Must specify `--identity`, `--codesign` and `--provisioning-profile` \
          when '--platform \(platform.rawValue)'
          """
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
              """
              `--provisioning-profile` is only available when building \
              visionOS and iOS apps
              """
            )
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

  func wrappedRun() throws {
    _ = try doBundling()
  }

  /// - Parameter dryRun: During a dry run, all of the validation steps are
  ///   performed without performing any side effects. This allows the
  ///   `RunCommand` to figure out where the output bundle will end up even
  ///   when the user instructs it to skip bundling.
  /// - Returns: A description of the structure of the bundler's output.
  func doBundling(dryRun: Bool = false) throws -> BundlerOutputStructure {
    // Time execution so that we can report it to the user.
    let (elapsed, bundlerOutputStructure) = try Stopwatch.time {
      // Load configuration
      let packageDirectory = arguments.packageDirectory ?? URL.currentDirectory
      let scratchDirectory =
        arguments.scratchDirectory ?? (packageDirectory / ".build")

      let (appName, appConfiguration, configuration) = try Self.getConfiguration(
        arguments.appName,
        packageDirectory: packageDirectory,
        context: ConfigurationFlattener.Context(platform: arguments.platform),
        customFile: arguments.configurationFileOverride
      )

      if !Self.validateArguments(
        arguments, platform: arguments.platform, skipBuild: skipBuild,
        builtWithXcode: builtWithXcode)
      {
        Foundation.exit(1)
      }

      // Get relevant configuration
      let architectures = getArchitectures(platform: arguments.platform)

      let outputDirectory = Self.getOutputDirectory(
        arguments.outputDirectory,
        scratchDirectory: scratchDirectory
      )

      // Load package manifest
      log.info("Loading package manifest")
      let manifest = try SwiftPackageManager.loadPackageManifest(from: packageDirectory)
        .unwrap()

      let platformVersion = manifest.platformVersion(for: arguments.platform)
      let buildContext = SwiftPackageManager.BuildContext(
        packageDirectory: packageDirectory,
        scratchDirectory: scratchDirectory,
        configuration: arguments.buildConfiguration,
        architectures: architectures,
        platform: arguments.platform,
        platformVersion: platformVersion,
        additionalArguments: arguments.additionalSwiftPMArguments,
        hotReloadingEnabled: hotReloadingEnabled
      )

      // Get build output directory
      let productsDirectory =
        try arguments.productsDirectory
        ?? SwiftPackageManager.getProductsDirectory(buildContext).unwrap()

      var bundlerContext = BundlerContext(
        appName: appName,
        packageName: manifest.displayName,
        appConfiguration: appConfiguration,
        packageDirectory: packageDirectory,
        productsDirectory: productsDirectory,
        outputDirectory: outputDirectory,
        platform: arguments.platform,
        builtDependencies: [:]
      )

      // If this is a dry run, drop out just before we start actually do stuff.
      guard !dryRun else {
        return try Self.intendedOutput(
          of: arguments.bundler.bundler,
          context: bundlerContext,
          command: self,
          manifest: manifest
        )
      }

      let dependenciesScratchDirectory = outputDirectory / "projects"

      let dependencies = try ProjectBuilder.buildDependencies(
        appConfiguration.dependencies,
        packageConfiguration: configuration,
        packageDirectory: packageDirectory,
        scratchDirectory: dependenciesScratchDirectory,
        appProductsDirectory: productsDirectory,
        appName: appName,
        platform: buildContext.platform,
        dryRun: skipBuild
      ).unwrap()
      bundlerContext.builtDependencies = dependencies

      if !skipBuild {
        // Copy built library products
        log.info("Copying dependencies")

        if !FileManager.default.itemExists(at: productsDirectory, withType: .directory) {
          try FileManager.default.createDirectory(
            at: productsDirectory,
            withIntermediateDirectories: true
          )
        }

        for (_, dependency) in dependencies {
          guard
            dependency.product.type == .dynamicLibrary
              || dependency.product.type == .staticLibrary
          else {
            continue
          }

          let destination = productsDirectory / dependency.location.lastPathComponent
          if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
          }

          try FileManager.default.copyItem(
            at: dependency.location,
            to: destination
          )
        }

        log.info("Starting \(buildContext.configuration.rawValue) build")
        try SwiftPackageManager.build(
          product: appConfiguration.product,
          buildContext: buildContext
        ).unwrap()
      }

      try Self.removeExistingOutputs(
        outputDirectory: outputDirectory,
        skip: [dependenciesScratchDirectory.lastPathComponent]
      ).unwrap()

      return try Self.bundle(
        with: arguments.bundler.bundler,
        context: bundlerContext,
        command: self,
        manifest: manifest
      )
    }

    if !dryRun {
      // Output the time elapsed along with the location of the produced app bundle.
      log.info(
        """
        Done in \(elapsed.secondsString). App bundle located at \
        '\(bundlerOutputStructure.bundle.relativePath)'
        """
      )
    }

    return bundlerOutputStructure
  }

  /// Removes the given output directory if it exists.
  static func removeExistingOutputs(
    outputDirectory: URL,
    skip excludedItems: [String]
  ) -> Result<Void, CLIError> {
    if FileManager.default.itemExists(at: outputDirectory, withType: .directory) {
      do {
        let contents = try FileManager.default.contentsOfDirectory(
          at: outputDirectory,
          includingPropertiesForKeys: nil
        )
        for item in contents {
          guard !excludedItems.contains(item.lastPathComponent) else {
            continue
          }
          try FileManager.default.removeItem(at: item)
        }
      } catch {
        return .failure(
          CLIError.failedToRemoveExistingOutputs(
            outputDirectory: outputDirectory,
            error
          )
        )
      }
    }
    return .success()
  }

  /// This generic function is required to operate on `any Bundler`s.
  static func bundle<B: Bundler>(
    with bundler: B.Type,
    context: BundlerContext,
    command: Self,
    manifest: PackageManifest
  ) throws -> BundlerOutputStructure {
    try bundler.computeContext(
      context: context,
      command: command,
      manifest: manifest
    )
    .andThen { additionalContext in
      bundler.bundle(context, additionalContext)
    }
    .unwrap()
  }

  /// This generic function is required to operate on `any Bundler`s.
  static func intendedOutput<B: Bundler>(
    of bundler: B.Type,
    context: BundlerContext,
    command: Self,
    manifest: PackageManifest
  ) throws -> BundlerOutputStructure {
    try bundler.computeContext(
      context: context,
      command: command,
      manifest: manifest
    )
    .map { additionalContext in
      bundler.intendedOutput(in: context, additionalContext)
    }
    .unwrap()
  }

  /// Gets the configuration for the specified app.
  ///
  /// If no app is specified, the first app is used (unless there are multiple
  /// apps, in which case a failure is returned).
  /// - Parameters:
  ///   - appName: The app's name.
  ///   - packageDirectory: The package's root directory.
  ///   - context: The context used to evaluate configuration overlays.
  ///   - customFile: A custom configuration file not at the standard location.
  /// - Returns: The app's configuration if successful.
  static func getConfiguration(
    _ appName: String?,
    packageDirectory: URL,
    context: ConfigurationFlattener.Context,
    customFile: URL? = nil
  ) throws -> (
    appName: String,
    appConfiguration: AppConfiguration.Flat,
    configuration: PackageConfiguration.Flat
  ) {
    if let configuration = Self.bundlerConfiguration {
      return configuration
    }

    let configuration = try PackageConfiguration.load(
      fromDirectory: packageDirectory,
      customFile: customFile
    ).unwrap()

    let flatConfiguration = try ConfigurationFlattener.flatten(
      configuration,
      with: context
    ).unwrap()

    let (appName, appConfiguration) = try flatConfiguration.getAppConfiguration(
      appName
    ).unwrap()

    Self.bundlerConfiguration = (appName, appConfiguration, flatConfiguration)
    return (appName, appConfiguration, flatConfiguration)
  }

  /// Unwraps an optional output directory and returns the default output
  /// directory if it's `nil`.
  /// - Parameters:
  ///   - outputDirectory: The output directory. Returned as-is if not `nil`.
  ///   - scratchDirectory: The configured scratch directory.
  /// - Returns: The output directory to use.
  static func getOutputDirectory(
    _ outputDirectory: URL?,
    scratchDirectory: URL
  ) -> URL {
    return outputDirectory ?? scratchDirectory.appendingPathComponent("bundler")
  }
}
