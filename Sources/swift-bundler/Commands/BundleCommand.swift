import Foundation
import StackOtterArgParser
import X509

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
        current host platform. Supported bundlers: \
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

  static func resolveCodesigningContext(
    codesignArgument: Bool?,
    identityArgument: String?,
    provisioningProfile: URL?,
    entitlements: URL?,
    platform: Platform
  ) async throws -> BundlerContext.DarwinCodeSigningContext? {
    guard let platform = platform.asApplePlatform else {
      let invalidArguments = [
        ("--codesign", codesignArgument == true),
        ("--identity", identityArgument != nil),
        ("--entitlements", entitlements != nil),
        ("--provisioning-profile", provisioningProfile != nil),
      ].filter { $0.1 }.map { $0.0 }

      guard invalidArguments.count == 0 else {
        let list = invalidArguments.map { "'\($0)'" }
          .joinedGrammatically(
            withTrailingVerb: Verb(
              singular: "isn't",
              plural: "aren't"
            )
          )
        throw CLIError.failedToResolveCodesigningConfiguration(
          reason: "\(list) supported when targeting '\(platform.name)'"
        )
      }

      return nil
    }

    let codesign: Bool
    if platform.requiresProvisioningProfiles {
      if codesignArgument == nil || codesignArgument == true {
        codesign = true
      } else {
        throw CLIError.failedToResolveCodesigningConfiguration(
          reason: """
            \(platform.platform.name) is incompatible with '--no-codesign' \
            because it requires provisioning profiles
            """
        )
      }
    } else {
      codesign = codesignArgument ?? false
    }

    guard codesign else {
      let invalidArguments = [
        ("--identity", identityArgument != nil),
        ("--entitlements", entitlements != nil),
        ("--provisioning-profile", provisioningProfile != nil),
      ].filter { $0.1 }.map { $0.0 }
      guard invalidArguments.count == 0 else {
        let list = invalidArguments.map { "'\($0)'" }
          .joinedGrammatically(withTrailingVerb: .be)
        throw CLIError.failedToResolveCodesigningConfiguration(
          reason: "\(list) invalid when not codesigning"
        )
      }
      return nil
    }

    do {
      let identity: CodeSigner.Identity
      if let identityShortName = identityArgument {
        identity = try await CodeSigner.resolveIdentity(shortName: identityShortName)
          .unwrap()
      } else {
        let identities = try await CodeSigner.enumerateIdentities().unwrap()

        guard let firstIdentity = identities.first else {
          throw CLIError.failedToResolveCodesigningConfiguration(
            reason: """
              No codesigning identities found. Please sign into Xcode and try again.
              """
          )
        }

        if identities.count > 1 {
          log.info("Multiple codesigning identities found, using \(firstIdentity.name)")
        }

        identity = firstIdentity
      }

      return BundlerContext.DarwinCodeSigningContext(
        identity: identity,
        entitlements: entitlements,
        manualProvisioningProfile: provisioningProfile
      )
    } catch {
      // Add clarification in case codesigning inference causes any confusion
      if codesignArgument == nil {
        log.info(
          """
          \(platform.platform.name) requires codesigning, so '--codesign' has \
          been inferred.
          """
        )
      }
      throw error
    }
  }

  /// Resolves the target platform, returning the resolved target device as
  /// well if the user specified a target device.
  static func resolvePlatform(
    platform: Platform?,
    deviceSpecifier: String?,
    simulatorSpecifier: String?
  ) async throws -> (Platform, Device?) {
    if let platform = platform, deviceSpecifier == nil, simulatorSpecifier == nil {
      return (platform, nil)
    }

    let device = try await resolveDevice(
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
  ) async throws -> Device {
    // '--device' and '--simulator' are mutually exclusive
    guard deviceSpecifier == nil || simulatorSpecifier == nil else {
      throw CLIError.failedToResolveTargetDevice(
        reason: "'--device' and '--simulator' cannot be used at the same time"
      )
    }

    if let deviceSpecifier {
      // This will also find simulators (--device can be used to specify any
      // destination).
      return try await DeviceManager.resolve(
        specifier: deviceSpecifier,
        platform: platform
      ).unwrap()
    } else if let simulatorSpecifier {
      if let platform = platform, !platform.isSimulator {
        throw CLIError.failedToResolveTargetDevice(
          reason: "'--simulator' is incompatible with '--platform \(platform)'"
        )
      }

      let matchedSimulators = try await SimulatorManager.listAvailableSimulators(
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
      switch platform {
        case .none, hostPlatform.platform:
          return Device.host(hostPlatform)
        case .some(let platform) where platform.isSimulator:
          let matchedSimulators = try await SimulatorManager.listAvailableSimulators().unwrap()
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
              reason: Output {
                """
                No booted simulators found for platform '\(platform)'. Boot \
                \(platform.os.rawValue.withIndefiniteArticle) simulator, or \
                specify a simulator to use via '--simulator <id-or-search-term>'

                """

                Section("List available simulators") {
                  ExampleCommand("swift bundler simulators list")
                }

                Section("Boot a simulator", trailingNewline: false) {
                  ExampleCommand("swift bundler simulators boot <id-or-name>")
                }
              }.description
            )
          }

          if matchedSimulators.count > 1 {
            log.warning(
              "Found multiple booted \(platform.os.rawValue) simulators, using '\(simulator.name)'"
            )
          }

          return simulator.device
        case .some(let platform):
          let reason =
            Output {
              """
              '--platform \(platform.name)' requires '--device <id-or-search-term>'

              """

              Section("List available devices", trailingNewline: false) {
                ExampleCommand("swift bundler devices list")
              }
            }.description
          throw CLIError.failedToResolveTargetDevice(reason: reason)
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
      case .linux, .windows, .iOSSimulator, .visionOSSimulator, .tvOSSimulator:
        architectures = [BuildArchitecture.current]
    }

    return architectures
  }

  func wrappedRun() async throws {
    let (platform, device) = try await Self.resolvePlatform(
      platform: arguments.platform,
      deviceSpecifier: arguments.deviceSpecifier,
      simulatorSpecifier: arguments.simulatorSpecifier
    )
    _ = try await doBundling(resolvedPlatform: platform, resolvedDevice: device)
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
  ) async throws -> BundlerOutputStructure {
    let resolvedCodesigningContext = try await Self.resolveCodesigningContext(
      codesignArgument: arguments.codesign,
      identityArgument: arguments.identity,
      provisioningProfile: arguments.provisioningProfile,
      entitlements: arguments.entitlements,
      platform: resolvedPlatform
    )

    // Time execution so that we can report it to the user.
    let (elapsed, bundlerOutputStructure) = try await Stopwatch.time {
      // Load configuration
      let packageDirectory = arguments.packageDirectory ?? URL.currentDirectory
      let scratchDirectory =
        arguments.scratchDirectory ?? (packageDirectory / ".build")

      let (appName, appConfiguration, configuration) = try await Self.getConfiguration(
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
      let manifest = try await SwiftPackageManager.loadPackageManifest(from: packageDirectory)
        .unwrap()

      let platformVersion =
        resolvedPlatform.asApplePlatform.map { platform in
          manifest.platformVersion(for: platform.os)
        } ?? nil
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
        hotReloadingEnabled: hotReloadingEnabled,
        isGUIExecutable: true
      )

      // Get build output directory
      let productsDirectory: URL

      if !isUsingXcodebuild {
        if let argumentsProductsDirectory = arguments.productsDirectory {
          productsDirectory = argumentsProductsDirectory
        } else {
          productsDirectory = try await SwiftPackageManager.getProductsDirectory(buildContext)
            .unwrap()
        }
      } else {
        let archString = architectures.compactMap({ $0.rawValue }).joined(separator: "_")
        // xcodebuild adds a platform suffix to the products directory for
        // certain platforms. E.g. it's 'Release-xrsimulator' for visionOS.
        let productsDirectoryBase = arguments.buildConfiguration.rawValue.capitalized
        let platformSuffix = resolvedPlatform == .macOS ? "" : "-\(resolvedPlatform.sdkName)"
        productsDirectory =
          arguments.productsDirectory
          ?? (packageDirectory
            / ".build/\(archString)-apple-\(resolvedPlatform.sdkName)"
            / "Build/Products/\(productsDirectoryBase)\(platformSuffix)")
      }

      var bundlerContext = BundlerContext(
        appName: appName,
        packageName: manifest.name,
        appConfiguration: appConfiguration,
        packageDirectory: packageDirectory,
        productsDirectory: productsDirectory,
        outputDirectory: outputDirectory,
        platform: resolvedPlatform,
        device: resolvedDevice,
        darwinCodeSigningContext: resolvedCodesigningContext,
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

      let dependencies = try await ProjectBuilder.buildDependencies(
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
        if !FileManager.default.itemExists(at: productsDirectory, withType: .directory) {
          try FileManager.default.createDirectory(
            at: productsDirectory,
            withIntermediateDirectories: true
          )
        }

        // Copy built library products
        if !dependencies.isEmpty {
          log.info("Copying dependencies")
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
          try await Xcodebuild.build(
            product: appConfiguration.product,
            buildContext: buildContext
          ).unwrap()
        } else {
          try await SwiftPackageManager.build(
            product: appConfiguration.product,
            buildContext: buildContext
          ).unwrap()
        }
      }

      try Self.removeExistingOutputs(
        outputDirectory: outputDirectory,
        skip: [dependenciesScratchDirectory.lastPathComponent]
      ).unwrap()

      return try await Self.bundle(
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
  ) async throws -> BundlerOutputStructure {
    try await bundler.computeContext(
      context: context,
      command: command,
      manifest: manifest
    ).andThen { additionalContext in
      await bundler.bundle(context, additionalContext)
    }.unwrap()
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
    ).map { additionalContext in
      bundler.intendedOutput(in: context, additionalContext)
    }.unwrap()
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
  ) async throws -> (
    appName: String,
    appConfiguration: AppConfiguration.Flat,
    configuration: PackageConfiguration.Flat
  ) {
    if let configuration = Self.bundlerConfiguration {
      return configuration
    }

    let configuration = try await PackageConfiguration.load(
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
