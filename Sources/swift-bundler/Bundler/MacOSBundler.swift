import Foundation
import PackageModel

/// The bundler for creating macOS apps.
enum MacOSBundler: Bundler {
  /// Bundles the built executable and resources into a macOS app.
  ///
  /// ``build(product:in:buildConfiguration:universal:)`` should usually be called first.
  /// - Parameters:
  ///   - appName: The name to give the bundled app.
  ///   - packageName: The name of the package.
  ///   - appConfiguration: The app's configuration.
  ///   - packageDirectory: The root directory of the package containing the app.
  ///   - productsDirectory: The directory containing the products from the build step.
  ///   - outputDirectory: The directory to output the app into.
  ///   - isXcodeBuild: Whether the build products were created by Xcode or not.
  ///   - universal: Whether the build products were built as universal binaries or not.
  ///   - standAlone: If `true`, the app bundle will not depend on any system-wide dependencies
  ///     being installed (such as gtk).
  ///   - codesigningIdentity: If not `nil`, the app will be codesigned using the given identity.
  ///   - provisioningProfile: If not `nil`, this provisioning profile will get embedded in the app.
  ///   - platformVersion: The platform version that the executable was built for.
  ///   - targetingSimulator: Does nothing for macOS builds.
  /// - Returns: If a failure occurs, it is returned.
  static func bundle(
    appName: String,
    packageName: String,
    appConfiguration: AppConfiguration,
    packageDirectory: URL,
    productsDirectory: URL,
    outputDirectory: URL,
    isXcodeBuild: Bool,
    universal: Bool,
    standAlone: Bool,
    codesigningIdentity: String?,
    provisioningProfile: URL?,
    platformVersion: String,
    targetingSimulator: Bool
  ) -> Result<Void, Error> {
    log.info("Bundling '\(appName).app'")

    let executableArtifact = productsDirectory.appendingPathComponent(appConfiguration.product)

    let appBundle = outputDirectory.appendingPathComponent("\(appName).app")
    let appContents = appBundle.appendingPathComponent("Contents")
    let appExecutable = appContents.appendingPathComponent("MacOS/\(appName)")
    let appResources = appContents.appendingPathComponent("Resources")
    let appDynamicLibrariesDirectory = appContents.appendingPathComponent("Libraries")

    let createAppIconIfPresent: () -> Result<Void, MacOSBundlerError> = {
      if let path = appConfiguration.icon {
        let icon = packageDirectory.appendingPathComponent(path)
        return Self.createAppIcon(icon: icon, outputDirectory: appResources)
      }
      return .success()
    }

    let copyResourcesBundles: () -> Result<Void, MacOSBundlerError> = {
      ResourceBundler.copyResources(
        from: productsDirectory,
        to: appResources,
        fixBundles: !isXcodeBuild && !universal,
        platform: .macOS,
        platformVersion: platformVersion,
        packageName: packageName,
        productName: appConfiguration.product
      ).mapError { error in
        .failedToCopyResourceBundles(error)
      }
    }

    let copyDynamicLibraries: () -> Result<Void, MacOSBundlerError> = {
      DynamicLibraryBundler.copyDynamicLibraries(
        dependedOnBy: appExecutable,
        to: appDynamicLibrariesDirectory,
        productsDirectory: productsDirectory,
        isXcodeBuild: isXcodeBuild,
        universal: universal,
        makeStandAlone: standAlone
      ).mapError { error in
        .failedToCopyDynamicLibraries(error)
      }
    }

    let sign: () -> Result<Void, MacOSBundlerError> = {
      if let identity = codesigningIdentity {
        return CodeSigner.signAppBundle(bundle: appBundle, identityId: identity).mapError { error in
          return .failedToCodesign(error)
        }
      } else {
        return .success()
      }
    }

    let bundleApp = flatten(
      { Self.createAppDirectoryStructure(at: outputDirectory, appName: appName) },
      { Self.copyExecutable(at: executableArtifact, to: appExecutable) },
      { Self.createMetadataFiles(at: appContents, appName: appName, appConfiguration: appConfiguration, macOSVersion: platformVersion) },
      createAppIconIfPresent,
      copyResourcesBundles,
      copyDynamicLibraries,
      sign
    )

    return bundleApp().mapError { (error: MacOSBundlerError) -> Error in
      return error
    }
  }

  // MARK: Private methods

  /// Creates the directory structure for an app.
  ///
  /// Creates the following structure:
  ///
  /// - `AppName.app`
  ///   - `Contents`
  ///     - `MacOS`
  ///     - `Resources`
  ///     - `Libraries`
  ///
  /// If the app directory already exists, it is deleted before continuing.
  ///
  /// - Parameters:
  ///   - outputDirectory: The directory to output the app to.
  ///   - appName: The name of the app.
  /// - Returns: A failure if directory creation fails.
  private static func createAppDirectoryStructure(at outputDirectory: URL, appName: String) -> Result<Void, MacOSBundlerError> {
    log.info("Creating '\(appName).app'")
    let fileManager = FileManager.default

    let appBundleDirectory = outputDirectory.appendingPathComponent("\(appName).app")
    let appContents = appBundleDirectory.appendingPathComponent("Contents")
    let appResources = appContents.appendingPathComponent("Resources")
    let appMacOS = appContents.appendingPathComponent("MacOS")
    let appDynamicLibrariesDirectory = appContents.appendingPathComponent("Libraries")

    do {
      if fileManager.itemExists(at: appBundleDirectory, withType: .directory) {
        try fileManager.removeItem(at: appBundleDirectory)
      }
      try fileManager.createDirectory(at: appResources)
      try fileManager.createDirectory(at: appMacOS)
      try fileManager.createDirectory(at: appDynamicLibrariesDirectory)
      return .success()
    } catch {
      return .failure(.failedToCreateAppBundleDirectoryStructure(bundleDirectory: appBundleDirectory, error))
    }
  }

  /// Copies the built executable into the app bundle.
  /// - Parameters:
  ///   - source: The location of the built executable.
  ///   - destination: The target location of the built executable (the file not the directory).
  /// - Returns: If an error occus, a failure is returned.
  private static func copyExecutable(at source: URL, to destination: URL) -> Result<Void, MacOSBundlerError> {
    log.info("Copying executable")
    do {
      try FileManager.default.copyItem(at: source, to: destination)
      return .success()
    } catch {
      return .failure(.failedToCopyExecutable(source: source, destination: destination, error))
    }
  }

  /// Creates an app's `PkgInfo` and `Info.plist` files.
  /// - Parameters:
  ///   - outputDirectory: Should be the app's `Contents` directory.
  ///   - appName: The app's name.
  ///   - appConfiguration: The app's configuration.
  ///   - macOSVersion: The macOS version to target.
  /// - Returns: If an error occurs, a failure is returned.
  private static func createMetadataFiles(
    at outputDirectory: URL,
    appName: String,
    appConfiguration: AppConfiguration,
    macOSVersion: String
  ) -> Result<Void, MacOSBundlerError> {
    log.info("Creating 'PkgInfo'")
    let pkgInfoFile = outputDirectory.appendingPathComponent("PkgInfo")
    do {
      var pkgInfoBytes: [UInt8] = [0x41, 0x50, 0x50, 0x4c, 0x3f, 0x3f, 0x3f, 0x3f]
      let pkgInfoData = Data(bytes: &pkgInfoBytes, count: pkgInfoBytes.count)
      try pkgInfoData.write(to: pkgInfoFile)
    } catch {
      return .failure(.failedToCreatePkgInfo(file: pkgInfoFile, error))
    }

    log.info("Creating 'Info.plist'")
    let infoPlistFile = outputDirectory.appendingPathComponent("Info.plist")
    return PlistCreator.createAppInfoPlist(
      at: infoPlistFile,
      appName: appName,
      configuration: appConfiguration,
      platform: .macOS,
      platformVersion: macOSVersion
    ).mapError { error in
      .failedToCreateInfoPlist(error)
    }
  }

  /// If given an `icns`, the `icns` gets copied to the output directory. If given a `png`, an `AppIcon.icns` is created from the `png`.
  ///
  /// The files are not validated any further than checking their file extensions.
  /// - Parameters:
  ///   - icon: The app's icon. Should be either an `icns` file or a 1024x1024 `png` with an alpha channel.
  ///   - outputDirectory: Should be the app's `Resources` directory.
  /// - Returns: If the png exists and there is an error while converting it to `icns`, a failure is returned.
  ///   If the file is neither an `icns` or a `png`, a failure is also returned.
  private static func createAppIcon(icon: URL, outputDirectory: URL) -> Result<Void, MacOSBundlerError> {
    // Copy `AppIcon.icns` if present
    if icon.pathExtension == "icns" {
      log.info("Copying '\(icon.lastPathComponent)'")
      let destination = outputDirectory.appendingPathComponent("AppIcon.icns")
      do {
        try FileManager.default.copyItem(at: icon, to: destination)
        return .success()
      } catch {
        return .failure(.failedToCopyICNS(source: icon, destination: destination, error))
      }
    } else if icon.pathExtension == "png" {
      log.info("Creating 'AppIcon.icns' from '\(icon.lastPathComponent)'")
      return IconSetCreator.createIcns(from: icon, outputDirectory: outputDirectory)
        .mapError { error in
          .failedToCreateIcon(error)
        }
    }

    return .failure(.invalidAppIconFile(icon))
  }
}
