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
  ///   - packageDirectory: The root directory of the package containing the product.
  ///   - configuration: The build configuration to use.
  ///   - architectures: The set of architectures to build for.
  ///   - platform: The platform to build for.
  ///   - platformVersion: The platform version to build for.
  ///   - hotReloadingEnabled: Controls whether the hot reloading environment variables
  ///     are added to the build command or not.
  /// - Returns: If an error occurs, returns a failure.
  static func build(
    product: String,
    packageDirectory: URL,
    configuration: BuildConfiguration,
    architectures: [BuildArchitecture],
    platform: Platform,
    platformVersion: String,
    outputDirectory: URL,
    hotReloadingEnabled: Bool = false
  ) -> Result<Void, XcodeBuildManagerError> {
    log.info("Starting \(configuration.rawValue) build")

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
          directory: packageDirectory,
          runSilentlyWhenNotVerbose: false
        )
      case .failure(let error):
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

    let archString = architectures.flatMap({ $0.rawValue }).joined(separator: "_")

    var additionalArgs: [String] = []
    if platform != .macOS {
      // retrieving simulators for the -destination argument is only relevant for non-macOS platforms.
      guard let simulators = try? SimulatorManager.listAvailableOSSimulators(for: platform).unwrap() else {
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
                platform: platform.name.replacingOccurrences(of: "Simulator", with: " Simulator"),
                OS: os
              )
            )
          }
        }
      }

      // ----- some filters -----

      // we only care about matching the specifed platform name.
      let forPlatform: (XcodeBuildDestination) -> Bool = { simulator in
        return simulator.platform.contains(platform.name.replacingOccurrences(of: "Simulator", with: " Simulator"))
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
        "-configuration", configuration.rawValue.capitalized,
        "-usePackageSupportBuiltinSCM",
        "-derivedDataPath", packageDirectory.appendingPathComponent(".build/\(archString)-apple-\(platform.sdkName)").path,
        "-archivePath", outputDirectory.appendingPathComponent(product).path
      ] + additionalArgs,
      directory: packageDirectory,
      runSilentlyWhenNotVerbose: false
    )

    if hotReloadingEnabled {
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
}
