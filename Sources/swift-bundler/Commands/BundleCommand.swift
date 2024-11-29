/* -----------------------------------------------------------
 * :: :  D  E  S  I  G  N  :                                ::
 * -----------------------------------------------------------
 * @swift
 *
 *
 *                    copyright (c) 2024 the swift collective.
 *                                        All Rights Reserved.
 * -----------------------------------------------------------
 *  . x x x . o o o . x x x . : : : .    o  x  o    . : : : .
 * ----------------------------------------------------------- */

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
          "Treats the products in the products directory as if they were built by Xcode (which is the same as universal builds by SwiftPM)."
          + " Can only be set when `--skip-build` is supplied."
      ))
  #endif
  var builtWithXcode = false

  var hotReloadingEnabled = false

  /// Used to avoid loading configuration twice when RunCommand is used.
  static var app: (name: String, app: AppConfiguration)? // TODO: fix this weird pattern with a better config loading system

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
    _ = try await doBundling()
  }

  /// - Parameter dryRun: During a dry run, all of the validation steps are
  ///   performed without performing any side effects. This allows the
  ///   `RunCommand` to figure out where the output bundle will end up even
  ///   when the user instructs it to skip bundling.
  /// - Returns: A description of the structure of the bundler's output.
  func doBundling(dryRun: Bool = false) async throws -> BundlerOutputStructure {
    // Time execution so that we can report it to the user.
    let (elapsed, bundlerOutputStructure) = try await Stopwatch.time {
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
        builtWithXcode: builtWithXcode
      ) {
        Foundation.exit(1)
      }

      // Get relevant configuration
      let architectures = getArchitectures(platform: arguments.platform)

      var forceUsingXcodeBuild = arguments.xcodebuild
      // For all apple platforms (not including macOS), we generate xcode
      // support, because macOS cannot cross-compile for any of the other
      // darwin platforms like it can with linux, and thus we need to use
      // xcodebuild to build for these platforms (ex. visionOS, iOS, etc)
      if forceUsingXcodeBuild || ![Platform.linux, Platform.macOS].contains(arguments.platform) {
        forceUsingXcodeBuild = true
      }
      forceUsingXcodeBuild = arguments.noXcodebuild ? !arguments.noXcodebuild : forceUsingXcodeBuild

      if forceUsingXcodeBuild {
        // Terminate the program if the project is an Xcodeproj based project.
        let xcodeprojs = try FileManager.default.contentsOfDirectory(
          at: packageDirectory,
          includingPropertiesForKeys: nil
        ).filter({ $0.pathExtension.contains("xcodeproj") || $0.pathExtension.contains("xcworkspace") })
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
      let productsDirectory: URL
      
      if !forceUsingXcodeBuild {
        productsDirectory = try arguments.productsDirectory
          ?? SwiftPackageManager.getProductsDirectory(buildContext).unwrap()
      } else {
        let archString = architectures.compactMap({ $0.rawValue }).joined(separator: "_")
        // for some reason xcodebuild adds a platform suffix like Release-xrsimulator for visionOS
        // however; for macOS there is no platform suffix at all.
        let platformSuffix = arguments.platform == .macOS ? "" : "-\(arguments.platform.sdkName)"
        productsDirectory = arguments.productsDirectory
          ?? packageDirectory.appendingPathComponent(
            ".build/\(archString)-apple-\(arguments.platform.sdkName)/Build/Products/\(arguments.buildConfiguration.rawValue.capitalized)\(platformSuffix)"
          )
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

      // Create build job
      let build: () -> Result<Void, Error> = {
        if forceUsingXcodeBuild {
          XcodeBuildManager.build(
            product: appConfiguration.product,
            buildContext: buildContext
          ).mapError { error in
            return error
          }
        } else {
          SwiftPackageManager.build(
            product: appConfiguration.product,
            buildContext: buildContext
          ).mapError { error in
            return error
          }
        }
      }

      // If this is a dry run, drop out just before we start actually do stuff.
      guard !dryRun else {
        return try Self.intendedOutput(
          of: arguments.bundler.bundler,
          context: bundlerContext,
          command: self,
          manifest: manifest
        )
      }

      // Run all of the tasks that we've built up.
      if !skipBuild {
        try build().unwrap()
      }

      try Self.removeExistingOutputs(outputDirectory: outputDirectory).unwrap()
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
  static func removeExistingOutputs(outputDirectory: URL) -> Result<Void, CLIError> {
    if FileManager.default.itemExists(at: outputDirectory, withType: .directory) {
      do {
        try FileManager.default.removeItem(at: outputDirectory)
      }
      catch {
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
  static func bundle(
    with bundler: (some Bundler).Type,
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
  static func intendedOutput(
    of bundler: (some Bundler).Type,
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
  ///   - customFile: A custom configuration file not at the standard location.
  /// - Returns: The app's configuration if successful.
  static func getAppConfiguration(
    _ appName: String?,
    packageDirectory: URL,
    customFile: URL? = nil
  ) -> Result<(name: String, app: AppConfiguration), PackageConfigurationError> {
    if let app {
      return .success(app)
    }

    return PackageConfiguration.load(
      fromDirectory: packageDirectory,
      customFile: customFile
    ).andThen { configuration in
      configuration.getAppConfiguration(appName)
    }.ifSuccess { app in
      Self.app = app
    }
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
