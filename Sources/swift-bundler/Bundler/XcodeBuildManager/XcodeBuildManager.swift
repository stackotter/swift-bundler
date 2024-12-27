import Foundation
import Parsing
import StackOtterArgParser
import Version
import Yams

/// A utility for interacting with xcodebuild.
enum XcodeBuildManager {

  /// Builds the specified product using a Swift package target as an xcodebuild scheme.
  /// - Parameters:
  ///   - product: The product to build.
  ///   - buildContext: The context to build in.
  /// - Returns: If an error occurs, returns a failure.
  static func build(
    product: String,
    buildContext: SwiftPackageManager.BuildContext
  ) -> Result<Void, XcodeBuildManagerError> {
    let pipe = Pipe()
    let process: Process

    var xcbeautify: Process?
    let xcbeautifyCmd = Process.locate("xcbeautify")
    switch xcbeautifyCmd
    {
      case .success(let cmd):
        xcbeautify = Process.create(
          cmd,
          arguments: [
            "--disable-logging"
          ],
          directory: buildContext.packageDirectory,
          runSilentlyWhenNotVerbose: false
        )
      case .failure(_):
        #if os(macOS)
          let helpMsg = "brew install xcbeautify"
        #else
          let helpMsg = "mint install cpisciotta/xcbeautify"
        #endif
        log.warning("""
        xcbeautify was not found, for pretty build output please intall it with:\n
        \(helpMsg)
        """)
    }

    let archString = buildContext.architectures.compactMap({ $0.rawValue }).joined(separator: "_")

    var additionalArgs: [String] = []
    if buildContext.platform != .macOS {
      // retrieving simulators for the -destination argument is only relevant for non-macOS platforms.
      guard let simulators = try? SimulatorManager.listAvailableOSSimulators(for: buildContext.platform).unwrap() else {
        return .failure(.failedToRunXcodeBuild(
          command: "xcodebuild: could not retrieve list of available destinations.",
          .nonZeroExitStatus(-1)
        ))
      }

      var destinations: [XcodeBuildDestination] = []
      for os in simulators.map(\.OS) {
        for simulators in simulators.filter({ $0.OS == os }).map(\.simulators) {
          for simulator in simulators {
            destinations.append(
              XcodeBuildDestination(
                name: simulator.name, 
                platform: buildContext.platform.name.replacingOccurrences(of: "Simulator", with: " Simulator"),
                OS: os
              )
            )
          }
        }
      }

      // ----- some filters -----

      // we only care about matching the specifed platform name.
      let forPlatform: (XcodeBuildDestination) -> Bool = { simulator in
        return simulator.platform.contains(buildContext.platform.name.replacingOccurrences(of: "Simulator", with: " Simulator"))
      }
      // we prefer to ignore iPhone SE models.
      let removeBlacklisted: (XcodeBuildDestination) -> Bool = { simulator in
        return !simulator.name.contains("iPhone SE")
      }

      // ------------------------

      // 1. sort from highest to lowest semantic versions...
      destinations.sort { OSVersion($0.OS) > OSVersion($1.OS) }

      var destination: XcodeBuildDestination? = nil
      for dest in destinations.filter({ forPlatform($0) && removeBlacklisted($0) }) {
        // 2. because we grab the latest semantic version available here.
        destination = dest
        break
      }

      guard let buildDest = destination else {
        return .failure(.failedToRunXcodeBuild(
          command: "xcodebuild: could not retrieve a valid build destination.",
          .nonZeroExitStatus(-1)
        ))
      }

      additionalArgs += [
        "-destination", "platform=\(buildDest.platform),OS=\(buildDest.OS),name=\(buildDest.name)"
      ]
    } else {
      additionalArgs += [
        "-destination", "platform=macOS,arch=\(archString)"
      ]
    }

    process = Process.create(
      "xcodebuild",
      arguments: [
        "-scheme", product,
        "-configuration", buildContext.configuration.rawValue.capitalized,
        "-usePackageSupportBuiltinSCM",
        "-derivedDataPath", buildContext.packageDirectory.appendingPathComponent(".build/\(archString)-apple-\(buildContext.platform.sdkName)").path
      ] + additionalArgs,
      directory: buildContext.packageDirectory,
      runSilentlyWhenNotVerbose: false
    )

    if buildContext.hotReloadingEnabled {
      process.addEnvironmentVariables([
        "SWIFT_BUNDLER_HOT_RELOADING": "1"
      ])
    }

    // pipe xcodebuild output to xcbeautify.
    if let xcbeautify = xcbeautify {
      process.standardOutput = pipe
      xcbeautify.standardInput = pipe
    }

    do {
      try xcbeautify?.run()
    } catch {
      log.warning("xcbeautify error: \(error)")
    }

    return process.runAndWait().mapError { error in
      return .failedToRunXcodeBuild(
        command: "xcodebuild: failed to build.",
        error
      )
    }
  }

  /// Whether or not the bundle command utilizes xcodebuild instead of swiftpm.
  /// - Parameters:
  ///   - command: The subcommand for creating app bundles for a package.
  /// - Returns: Whether or not xcodebuild is invoked instead of swiftpm.
  static func isUsingXcodeBuild(for command: BundleCommand) -> Bool {
    var forceUsingXcodeBuild = command.arguments.xcodebuild
    // For all apple platforms (not including macOS), we generate xcode
    // support, because macOS cannot cross-compile for any of the other
    // darwin platforms like it can with linux, and thus we need to use
    // xcodebuild to build for these platforms (ex. visionOS, iOS, etc)
    if forceUsingXcodeBuild || ![Platform.linux, Platform.macOS].contains(command.arguments.platform) {
      forceUsingXcodeBuild = true
    }
    
    // Allows the '--no-xcodebuild' flag to be passed in, to override whether
    // or not the swiftpm-based build system is used, even for embedded apple
    // platforms (ex. visionOS, iOS, tvOS, watchOS).
    return command.arguments.noXcodebuild ? false : forceUsingXcodeBuild
  }
}
