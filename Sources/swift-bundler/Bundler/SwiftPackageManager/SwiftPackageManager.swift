import Foundation
import Parsing
import StackOtterArgParser
import Version

/// A utility for interacting with the Swift package manager and performing some other package
/// related operations.
enum SwiftPackageManager {
  /// Creates a new package using the given directory as the package's root directory.
  /// - Parameters:
  ///   - directory: The package's root directory (will be created if it doesn't exist).
  ///   - name: The name for the package.
  /// - Returns: If an error occurs, a failure is returned.
  static func createPackage(
    in directory: URL,
    name: String
  ) -> Result<Void, SwiftPackageManagerError> {
    // Create the package directory if it doesn't exist
    let createPackageDirectory: () -> Result<Void, SwiftPackageManagerError> = {
      if !FileManager.default.itemExists(at: directory, withType: .directory) {
        do {
          try FileManager.default.createDirectory(at: directory)
        } catch {
          return .failure(.failedToCreatePackageDirectory(directory, error))
        }
      }
      return .success()
    }

    // Run the init command
    let runInitCommand: () -> Result<Void, SwiftPackageManagerError> = {
      let arguments = [
        "package", "init",
        "--type=executable",
        "--name=\(name)",
      ]

      let process = Process.create(
        "swift",
        arguments: arguments,
        directory: directory)
      process.setOutputPipe(Pipe())

      return process.runAndWait()
        .mapError { error in
          .failedToRunSwiftInit(
            command: "swift \(arguments.joined(separator: " "))",
            error
          )
        }
    }

    // Create the configuration file
    let createConfigurationFile: () -> Result<Void, SwiftPackageManagerError> = {
      PackageConfiguration.createConfigurationFile(in: directory, app: name, product: name)
        .mapError { error in
          .failedToCreateConfigurationFile(error)
        }
    }

    // Compose the function
    let create = flatten(
      createPackageDirectory,
      runInitCommand,
      createConfigurationFile)

    return create()
  }

  /// Builds the specified product of a Swift package.
  /// - Parameters:
  ///   - product: The product to build.
  ///   - packageDirectory: The root directory of the package containing the product.
  ///   - configuration: The build configuration to use.
  ///   - architectures: The set of architectures to build for.
  ///   - platform: The platform to build for.
  ///   - platformVersion: The platform version to build for.
  /// - Returns: If an error occurs, returns a failure.
  static func build(
    product: String,
    packageDirectory: URL,
    configuration: BuildConfiguration,
    architectures: [BuildArchitecture],
    platform: Platform,
    platformVersion: String
  ) -> Result<Void, SwiftPackageManagerError> {
    log.info("Starting \(configuration.rawValue) build")

    return createBuildArguments(
      product: product,
      configuration: configuration,
      architectures: architectures,
      platform: platform,
      platformVersion: platformVersion
    ).flatMap { arguments in
      let process = Process.create(
        "swift",
        arguments: arguments,
        directory: packageDirectory,
        runSilentlyWhenNotVerbose: false
      )

      return process.runAndWait().mapError { error in
        return .failedToRunSwiftBuild(
          command: "swift \(arguments.joined(separator: " "))",
          error
        )
      }
    }
  }

  /// Creates the arguments for the Swift build command.
  /// - Parameters:
  ///   - product: The product to build.
  ///   - configuration: The build configuration to use.
  ///   - architectures: The architectures to build for.
  ///   - platform: The platform to build for.
  ///   - platformVersion: The platform version to target.
  /// - Returns: The build arguments, or a failure if an error occurs.
  static func createBuildArguments(
    product: String?,
    configuration: BuildConfiguration,
    architectures: [BuildArchitecture],
    platform: Platform,
    platformVersion: String
  ) -> Result<[String], SwiftPackageManagerError> {
    let platformArguments: [String]
    switch platform {
      case .iOS, .visionOS:
        let sdkPath: String
        switch getLatestSDKPath(for: platform) {
          case .success(let path):
            sdkPath = path
          case .failure(let error):
            return .failure(error)
        }

        let targetTriple = platform == .iOS
          ? "arm64-apple-ios\(platformVersion)"
          : "arm64-apple-xros\(platformVersion)"
        platformArguments =
          [
            "-sdk", sdkPath,
            "-target", targetTriple,
          ].flatMap { ["-Xswiftc", $0] }
          + [
            "--target=\(targetTriple)",
            "-isysroot", sdkPath,
          ].flatMap { ["-Xcc", $0] }
      case .iOSSimulator, .visionOSSimulator:
        let sdkPath: String
        switch getLatestSDKPath(for: platform) {
          case .success(let path):
            sdkPath = path
          case .failure(let error):
            return .failure(error)
        }

        // TODO: Make target triple generation generic
        let architecture = BuildArchitecture.current.rawValue
        let targetTriple = platform == .iOSSimulator 
          ? "\(architecture)-apple-ios\(platformVersion)-simulator" 
          : "\(architecture)-apple-xros\(platformVersion)-simulator" 
        platformArguments =
          [
            "-sdk", sdkPath,
            "-target", targetTriple,
          ].flatMap { ["-Xswiftc", $0] }
          + [
            "--target=\(targetTriple)",
            "-isysroot", sdkPath,
          ].flatMap { ["-Xcc", $0] }
      case .macOS, .linux:
        platformArguments = []
    }

    let architectureArguments = architectures.flatMap { architecture in
      ["--arch", architecture.argument(for: platform)]
    }

    let productArguments: [String]
    if let product = product {
      productArguments = ["--product", product]
    } else {
      productArguments = []
    }

    let arguments =
      [
        "build",
        "-c", configuration.rawValue,
      ] + productArguments + architectureArguments + platformArguments

    return .success(arguments)
  }

  /// Gets the path to the latest SDK for a given platform.
  /// - Parameter platform: The platform to get the SDK path for.
  /// - Returns: The SDK's path, or a failure if an error occurs.
  static func getLatestSDKPath(for platform: Platform) -> Result<String, SwiftPackageManagerError> {
    return Process.create(
      "/usr/bin/xcrun",
      arguments: [
        "--sdk", platform.sdkName,
        "--show-sdk-path",
      ]
    ).getOutput().map { output in
      return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }.mapError { error in
      return .failedToGetLatestSDKPath(platform, error)
    }
  }

  /// Gets the version of the current Swift installation.
  /// - Returns: The swift version, or a failure if an error occurs.
  static func getSwiftVersion() -> Result<Version, SwiftPackageManagerError> {
    let process = Process.create(
      "swift",
      arguments: ["--version"])

    return process.getOutput()
      .mapError { error in
        .failedToGetSwiftVersion(error)
      }
      .flatMap { output in
        // The first two examples are for release versions of Swift (the first on macOS, the second on Linux).
        // The next two examples are for snapshot versions of Swift (the first on macOS, the second on Linux).
        // Sample: "swift-driver version: 1.45.2 Apple Swift version 5.6 (swiftlang-5.6.0.323.62 clang-1316.0.20.8)"
        //     OR: "swift-driver version: 1.45.2 Swift version 5.6 (swiftlang-5.6.0.323.62 clang-1316.0.20.8)"
        //     OR: "Apple Swift version 5.9-dev (LLVM 464b04eb9b157e3, Swift 7203d52cb1e074d)"
        //     OR: "Swift version 5.9-dev (LLVM 464b04eb9b157e3, Swift 7203d52cb1e074d)"
        let parser = OneOf {
          Parse {
            "swift-driver version"
            Prefix { $0 != "(" }
            "(swiftlang-"
            Parse({ Version(major: $0, minor: $1, patch: $2) }) {
              Int.parser(of: Substring.self, radix: 10)
              "."
              Int.parser(of: Substring.self, radix: 10)
              "."
              Int.parser(of: Substring.self, radix: 10)
            }
            Rest<Substring>()
          }.map { (_: Substring, version: Version, _: Substring) in
            version
          }

          Parse {
            Optionally {
              "Apple "
            }
            "Swift version "
            Parse({ Version(major: $0, minor: $1, patch: 0) }) {
              Int.parser(of: Substring.self, radix: 10)
              "."
              Int.parser(of: Substring.self, radix: 10)
            }
            Rest<Substring>()
          }.map { (_: Void?, version: Version, _: Substring) in
            version
          }
        }

        do {
          let version = try parser.parse(output)
          return .success(version)
        } catch {
          return .failure(.invalidSwiftVersionOutput(output, error))
        }
      }
  }

  /// Gets the default products directory for the specified package and configuration.
  /// - Parameters:
  ///   - packageDirectory: The package's root directory.
  ///   - configuration: The current build configuration.
  ///   - architectures: The architectures that the build was for.
  ///   - platform: The platform that was built for.
  ///   - platformVersion: The platform version that was built for.
  /// - Returns: The default products directory. If `swift build --show-bin-path ... # extra args`
  ///   fails, a failure is returned.
  static func getProductsDirectory(
    in packageDirectory: URL,
    configuration: BuildConfiguration,
    architectures: [BuildArchitecture],
    platform: Platform,
    platformVersion: String
  ) -> Result<URL, SwiftPackageManagerError> {
    return createBuildArguments(
      product: nil,
      configuration: configuration,
      architectures: architectures,
      platform: platform,
      platformVersion: platformVersion
    ).flatMap { arguments in
      let process = Process.create(
        "swift",
        arguments: arguments + ["--show-bin-path"],
        directory: packageDirectory
      )

      return process.getOutput().map { output in
        let path = output.trimmingCharacters(in: .newlines)
        return URL(fileURLWithPath: path)
      }.mapError { error in
        return .failedToGetProductsDirectory(command: "swift " + process.argumentsString, error)
      }
    }
  }

  /// Loads a root package manifest from a package's root directory.
  /// - Parameter packageDirectory: The package's root directory.
  /// - Returns: The loaded manifest, or a failure if an error occurs.
  static func loadPackageManifest(
    from packageDirectory: URL
  ) async -> Result<PackageManifest, SwiftPackageManagerError> {
    // We used to use the SwiftPackageManager library to load package manifests,
    // but that caused issues when the library version didn't match the user's
    // installed Swift version and was very fiddly to fix. It was easier to just
    // hand roll a custom solution that we can update in the future to maintain
    // backwards compatability.
    //
    // Overview of loading a manifest manually:
    // - Compile and link manifest with Swift driver
    // - Run the resulting executable with `-fileno 1` as its args
    // - Parse the JSON that the executable outputs to stdout

    let manifestPath = packageDirectory.appendingPathComponent("Package.swift").path
    let temporaryDirectory = FileManager.default.temporaryDirectory
    let uuid = UUID().uuidString
    let temporaryExecutableFile =
      temporaryDirectory
      .appendingPathComponent("\(uuid)-PackageManifest").path

    #if os(Linux)
      let temporaryAutolinkFile =
        temporaryDirectory
        .appendingPathComponent("\(uuid)-PackageManifest.autolink").path
    #endif

    let targetInfo: SwiftTargetInfo
    switch self.getTargetInfo() {
      case .success(let info):
        targetInfo = info
      case .failure(let error):
        return .failure(error)
    }

    let manifestAPIDirectory = targetInfo.paths.runtimeResourcePath
      .appendingPathComponent("pm/ManifestAPI")

    var librariesPaths: [String] = []
    librariesPaths += targetInfo.paths.runtimeLibraryPaths.map(\.path)
    librariesPaths += [manifestAPIDirectory.path]

    var additionalSwiftArguments: [String] = []
    #if os(macOS)
      switch self.getLatestSDKPath(for: .macOS) {
        case .success(let path):
          librariesPaths += [path + "/usr/lib/swift"]
          additionalSwiftArguments += ["-sdk", path]
        case .failure(let error):
          return .failure(error)
      }
    #endif

    let toolsVersionProcess = Process.create("swift", arguments: ["package", "tools-version"])
    let toolsVersion: String
    let swiftMajorVersion: String
    switch toolsVersionProcess.getOutput() {
      case .success(let output):
        toolsVersion = output.trimmingCharacters(in: .whitespacesAndNewlines)
        swiftMajorVersion = String(toolsVersion.first!)
      case .failure(let error):
        // Provide a fallback tools version for when the tools version cannot be parsed.
        #if swift(>=6.0)
          // with Swift 6 just around the corner...
          let pkgDescVersion = "6.0.0"
        #elseif swift(>=5.9)
          // targeting visionOS needs a minimum tools version of 5.9.
          let pkgDescVersion = "5.9.0"
        #else
          let pkgDescVersion = "5.5.0"
        #endif
        toolsVersion = pkgDescVersion
        swiftMajorVersion = String(toolsVersion.first!)
        return .failure(.failedToParsePackageManifestToolsVersion(fallbackVersion: toolsVersion, error))
    }

    // Compile to object file
    let swiftArguments =
      [
        manifestPath,
        "-I", manifestAPIDirectory.path,
        "-Xlinker", "-rpath", "-Xlinker", manifestAPIDirectory.path,
        "-lPackageDescription",
        "-swift-version", swiftMajorVersion, "-package-description-version", toolsVersion,  
        "-disable-implicit-concurrency-module-import",
        "-disable-implicit-string-processing-module-import",
        "-o", temporaryExecutableFile,
      ]
      + librariesPaths.flatMap { ["-L", $0] }
      + additionalSwiftArguments

    let swiftProcess = Process.create("swiftc", arguments: swiftArguments)
    if case let .failure(error) = swiftProcess.runAndWait() {
      return .failure(.failedToCompilePackageManifest(error))
    }

    // Execute compiled manifest
    let process = Process.create(temporaryExecutableFile, arguments: ["-fileno", "1"])
    let json: String
    switch process.getOutput() {
      case .success(let output):
        json = output
      case .failure(let error):
        return .failure(.failedToExecutePackageManifest(error))
    }

    // Parse manifest output
    guard let jsonData = json.data(using: .utf8) else {
      return .failure(.failedToParsePackageManifestOutput(json: json, nil))
    }

    do {
      return .success(
        try JSONDecoder().decode(PackageManifest.self, from: jsonData)
      )
    } catch {
      return .failure(.failedToParsePackageManifestOutput(json: json, error))
    }
  }

  static func getTargetInfo() -> Result<SwiftTargetInfo, SwiftPackageManagerError> {
    // TODO: This could be a nice easy one to unit test
    let process = Process.create(
      "swift",
      arguments: ["-print-target-info"]
    )

    return process.getOutput().mapError { error in
      return .failedToGetTargetInfo(command: "swift " + process.argumentsString, error)
    }.flatMap { output in
      guard let data = output.data(using: .utf8) else {
        return .failure(.failedToParseTargetInfo(json: output, nil))
      }
      do {
        return .success(
          try JSONDecoder().decode(SwiftTargetInfo.self, from: data))
      } catch {
        return .failure(.failedToParseTargetInfo(json: output, error))
      }
    }
  }
}
