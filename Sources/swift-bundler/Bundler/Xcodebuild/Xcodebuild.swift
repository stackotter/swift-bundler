import Foundation
import Parsing
import StackOtterArgParser
import Version
import Yams

/// A utility for interacting with xcodebuild.
enum Xcodebuild {
  /// Builds the specified product using a Swift package target as an xcodebuild scheme.
  /// - Parameters:
  ///   - product: The product to build.
  ///   - buildContext: The context to build in.
  /// - Returns: If an error occurs, returns a failure.
  static func build(
    product: String,
    buildContext: SwiftPackageManager.BuildContext
  ) -> Result<Void, XcodebuildError> {
    guard let applePlatform = buildContext.platform.asApplePlatform else {
      return .failure(.unsupportedPlatform(buildContext.platform))
    }

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
        log.warning(
          """
          xcbeautify was not found, for pretty build output please intall it with:\n
          \(helpMsg)
          """
        )
    }

    let archString = buildContext.architectures
      .compactMap(\.rawValue)
      .joined(separator: "_")

    let destinationArguments: [String]
    if buildContext.platform == .macOS {
      destinationArguments = [
        "-destination",
        "platform=macOS,arch=\(archString)",
      ]
    } else {
      destinationArguments = [
        "-destination",
        "generic/platform=\(applePlatform.xcodeDestinationName)",
      ]
    }

    // TODO: Introduce a way to take custom xcodebuild arguments from the
    //   command line via --Xxcodebuild or something along those lines.

    process = Process.create(
      "xcodebuild",
      arguments: [
        "-scheme", product,
        "-configuration", buildContext.configuration.rawValue.capitalized,
        "-usePackageSupportBuiltinSCM",
        "-skipMacroValidation",
        "-derivedDataPath",
        buildContext.packageDirectory.appendingPathComponent(
          ".build/\(archString)-apple-\(buildContext.platform.sdkName)"
        ).path,
      ] + destinationArguments,
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
      return .failedToRunXcodebuild(
        command: "Failed to run xcodebuild.",
        error
      )
    }
  }

  /// Whether or not the bundle command utilizes xcodebuild instead of swiftpm.
  /// - Parameters:
  ///   - command: The subcommand for creating app bundles for a package.
  /// - Returns: Whether or not xcodebuild is invoked instead of swiftpm.
  static func isUsingXcodebuild(for command: BundleCommand) -> Bool {
    var forceUsingXcodebuild = command.arguments.xcodebuild
    // For non-macOS Apple platforms (e.g. iOS) we default to using the
    // xcodebuild builder instead of SwiftPM because SwiftPM doesn't
    // properly support cross-compiling to other Apple platforms from
    // macOS (and the workaround Swift Bundler uses to do so breaks down
    // when the package uses macros or has conditional dependencies in
    // its Package.swift).
    let platformBreaksWithoutXcodebuild =
      command.arguments.platform.isApplePlatform
      && command.arguments.platform != .macOS
    if forceUsingXcodebuild
      || platformBreaksWithoutXcodebuild
    {
      forceUsingXcodebuild = true
    }

    // Allows the '--no-xcodebuild' flag to be passed in, to override whether
    // or not the swiftpm-based build system is used, even for embedded apple
    // platforms (ex. visionOS, iOS, tvOS, watchOS).
    return command.arguments.noXcodebuild ? false : forceUsingXcodebuild
  }
}
