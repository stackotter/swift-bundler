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
    help: "Skip the build step."
  )
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

    if HostPlatform.hostPlatform == .linux && platform != .linux {
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
      if platform.isApplePlatform && platform != .macOS {
        if arguments.universal {
          log.error(
            """
            '--universal' is not compatible with '--platform \
            \(platform.rawValue)'
            """
          )
          return false
        }

        if !arguments.architectures.isEmpty {
          log.error(
            "'--arch' is not compatible with '--platform \(platform.rawValue)'"
          )
          return false
        }
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

      if platform.asApplePlatform?.requiresProvisioningProfiles == true,
        !arguments.shouldCodesign || arguments.identity == nil
      {
        log.error(
          """
          Must specify `--identity`, `--codesign` when targeting \
          \(platform.rawValue)
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
              '--provisioning-profile' is only available when building \
              apps for physical iOS, visionOS and tvOS devices
              """
            )
            return false
          }
      }
    #else
      if builtWithXcode {
        log.error(
          """
          '--built-with-xcode' is only available on macOS
          """
        )
      }
    #endif

    return true
  }

  /// Resolves the target platform, returning the resolved target device as
  /// well if the user specified a target device.
  static func resolvePlatform(
    platform: Platform?,
    deviceSpecifier: String?,
    simulatorSpecifier: String?
  ) throws -> (Platform, Device?) {
    if let platform = platform, deviceSpecifier == nil, simulatorSpecifier == nil {
      return (platform, nil)
    }

    let device = try resolveDevice(
      platform: platform,
      deviceSpecifier: deviceSpecifier,
      simulatorSpecifier: simulatorSpecifier
    )
    return (device.platform, device)
  }

  static func resolveDevice(
    platform: Platform?,
    deviceSpecifier: String?,
    simulatorSpecifier: String?
  ) throws -> Device {
    // '--device' and '--simulator' are mutually exclusive
    guard deviceSpecifier == nil || simulatorSpecifier == nil else {
      throw CLIError.failedToResolveTargetDevice(
        reason: "'--device' and '--simulator' cannot be used at the same time"
      )
    }

    if let deviceSpecifier {
      // This will also find simulators (--device can be used to specify any
      // destination).
      return try DeviceManager.resolve(
        specifier: deviceSpecifier,
        platform: platform
      ).unwrap()
    } else if let simulatorSpecifier {
      if let platform = platform, !platform.isSimulator {
        throw CLIError.failedToResolveTargetDevice(
          reason: "'--simulator' is incompatible with '--platform \(platform)'"
        )
      }

      let matchedSimulators = try SimulatorManager.listAvailableSimulators(
        searchTerm: simulatorSpecifier
      ).unwrap().sorted { first, second in
        // Put booted simulators first for convenience and put shorter names
        // first (otherwise there'd be no guarantee the "iPhone 15" matches
        // "iPhone 15" when both "iPhone 15" and "iPhone 15 Pro" exist, and
        // you'd be left with no way to disambiguate).
        if !first.isBooted && second.isBooted {
          return false
        } else if first.name.count > second.name.count {
          return false
        } else {
          return true
        }
      }.filter { simulator in
        // Filter out simulators with the wrong platform
        if let platform = platform {
          return simulator.os.simulatorPlatform.platform == platform
        } else {
          return true
        }
      }

      guard let simulator = matchedSimulators.first else {
        let platformCondition = platform.map { " with platform '\($0)'" } ?? ""
        throw CLIError.failedToResolveTargetDevice(
          reason: """
            No simulator found matching '\(simulatorSpecifier)'\(platformCondition). Use \
            'swift bundler simulators list' to list available simulators.
            """
        )
      }

      if matchedSimulators.count > 1 {
        log.warning(
          "Multiple simulators matched '\(simulatorSpecifier)', using '\(simulator.name)'"
        )
      }

      return simulator.device
    } else {
      let hostPlatform = HostPlatform.hostPlatform
      if platform == nil || platform == hostPlatform.platform {
        return Device.host(hostPlatform)
      } else if let platform = platform, platform.isSimulator {
        let matchedSimulators = try SimulatorManager.listAvailableSimulators().unwrap()
          .filter { simulator in
            simulator.isBooted
              && simulator.isAvailable
              && simulator.os.simulatorPlatform.platform == platform
          }
          .sorted { first, second in
            first.name < second.name
          }

        guard let simulator = matchedSimulators.first else {
          throw CLIError.failedToResolveTargetDevice(
            reason: """
              No booted simulators found for platform '\(platform)'. Boot \
              \(platform.os.rawValue.withIndefiniteArticle) simulator or specify a simulator to use via '--simulator <id_or_search_term>'
              """
          )
        }

        if matchedSimulators.count > 1 {
          log.warning(
            "Found multiple booted \(platform.os.rawValue) simulators, using '\(simulator.name)'"
          )
        }

        return simulator.device
      } else {
        let platform = platform ?? hostPlatform.platform
        throw CLIError.failedToResolveTargetDevice(
          reason: """
            '--platform \(platform.name)' requires '--device <id_or_search_term>' \
            or '--simulator <id_or_search_term>'
            """
        )
      }
    }
  }

  func getArchitectures(platform: Platform) -> [BuildArchitecture] {
    let architectures: [BuildArchitecture]
    switch platform {
      case .macOS:
        if arguments.universal {
          architectures = [.arm64, .x86_64]
        } else {
          architectures =
            !arguments.architectures.isEmpty
            ? arguments.architectures
            : [BuildArchitecture.current]
        }
      case .iOS, .visionOS, .tvOS:
        architectures = [.arm64]
      case .linux, .iOSSimulator, .visionOSSimulator, .tvOSSimulator:
        architectures = [BuildArchitecture.current]
    }

    return architectures
  }

  func wrappedRun() throws {
    let (platform, device) = try Self.resolvePlatform(
      platform: arguments.platform,
      deviceSpecifier: arguments.deviceSpecifier,
      simulatorSpecifier: arguments.simulatorSpecifier
    )
    _ = try doBundling(resolvedPlatform: platform, resolvedDevice: device)
  }

  /// - Parameters
  ///   - dryRun: During a dry run, all of the validation steps are
  ///     performed without performing any side effects. This allows the
  ///     `RunCommand` to figure out where the output bundle will end up even
  ///     when the user instructs it to skip bundling.
  ///   - resolvedPlatform: The target platform resolved from the various
  ///     arguments users can use to specify it. This parameter purely exists
  ///     to allow ``RunCommand`` to avoid resolving the target platform twice
  ///     (once for its own use and once when this method gets called).
  ///   - resolvedDevice: Must be provided when provisioning profiles are
  ///     expected to be generated.
  /// - Returns: A description of the structure of the bundler's output.
  func doBundling(
    dryRun: Bool = false,
    resolvedPlatform: Platform,
    resolvedDevice: Device? = nil
  ) throws -> BundlerOutputStructure {
    // Time execution so that we can report it to the user.
    let (elapsed, bundlerOutputStructure) = try Stopwatch.time {
      // Load configuration
      let packageDirectory = arguments.packageDirectory ?? URL.currentDirectory
      let scratchDirectory =
        arguments.scratchDirectory ?? (packageDirectory / ".build")

      let (appName, appConfiguration, configuration) = try Self.getConfiguration(
        arguments.appName,
        packageDirectory: packageDirectory,
        context: ConfigurationFlattener.Context(platform: resolvedPlatform),
        customFile: arguments.configurationFileOverride
      )

      guard
        Self.validateArguments(
          arguments,
          platform: resolvedPlatform,
          skipBuild: skipBuild,
          builtWithXcode: builtWithXcode
        )
      else {
        Foundation.exit(1)
      }

      // Get relevant configuration
      let architectures = getArchitectures(platform: resolvedPlatform)

      // Whether or not we are building with xcodebuild instead of swiftpm.
      let isUsingXcodebuild = Xcodebuild.isUsingXcodebuild(
        for: self,
        resolvedPlatform: resolvedPlatform
      )

      if isUsingXcodebuild {
        // Terminate the program if the project is an Xcodeproj based project.
        let xcodeprojs = try FileManager.default.contentsOfDirectory(
          at: packageDirectory,
          includingPropertiesForKeys: nil
        ).filter({
          $0.pathExtension.contains("xcodeproj") || $0.pathExtension.contains("xcworkspace")
        })
        guard xcodeprojs.isEmpty else {
          for xcodeproj in xcodeprojs {
            if xcodeproj.path.contains("xcodeproj") {
              log.error("An xcodeproj was located at the following path: \(xcodeproj.path)")
            } else if xcodeproj.path.contains("xcworkspace") {
              log.error("An xcworkspace was located at the following path: \(xcodeproj.path)")
            }
          }
          throw CLIError.invalidXcodeprojDetected
        }
      }

      let outputDirectory = Self.getOutputDirectory(
        arguments.outputDirectory,
        scratchDirectory: scratchDirectory
      )

      // Load package manifest
      log.info("Loading package manifest")
      let manifest = try SwiftPackageManager.loadPackageManifest(from: packageDirectory)
        .unwrap()

      let platformVersion = manifest.platformVersion(for: resolvedPlatform)
      let buildContext = SwiftPackageManager.BuildContext(
        packageDirectory: packageDirectory,
        scratchDirectory: scratchDirectory,
        configuration: arguments.buildConfiguration,
        architectures: architectures,
        platform: resolvedPlatform,
        platformVersion: platformVersion,
        additionalArguments: isUsingXcodebuild
          ? arguments.additionalXcodeBuildArguments
          : arguments.additionalSwiftPMArguments,
        hotReloadingEnabled: hotReloadingEnabled
      )

      // Get build output directory
      let productsDirectory: URL

      if !isUsingXcodebuild {
        productsDirectory =
          try arguments.productsDirectory
          ?? SwiftPackageManager.getProductsDirectory(buildContext).unwrap()
      } else {
        let archString = architectures.compactMap({ $0.rawValue }).joined(separator: "_")
        // xcodebuild adds a platform suffix to the products directory for
        // certain platforms. E.g. it's 'Release-xrsimulator' for visionOS.
        let productsDirectoryBase = arguments.buildConfiguration.rawValue.capitalized
        let platformSuffix = arguments.platform == .macOS ? "" : "-\(resolvedPlatform.sdkName)"
        productsDirectory =
          arguments.productsDirectory
          ?? (packageDirectory
            / ".build/\(archString)-apple-\(resolvedPlatform.sdkName)"
            / "Build/Products/\(productsDirectoryBase)\(platformSuffix)")
      }

      var bundlerContext = BundlerContext(
        appName: appName,
        packageName: manifest.displayName,
        appConfiguration: appConfiguration,
        packageDirectory: packageDirectory,
        productsDirectory: productsDirectory,
        outputDirectory: outputDirectory,
        platform: resolvedPlatform,
        device: resolvedDevice,
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
        if isUsingXcodebuild {
          try Xcodebuild.build(
            product: appConfiguration.product,
            buildContext: buildContext
          ).unwrap()
        } else {
          try SwiftPackageManager.build(
            product: appConfiguration.product,
            buildContext: buildContext
          ).unwrap()
        }
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
