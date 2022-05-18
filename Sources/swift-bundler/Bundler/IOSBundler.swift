import Foundation
import PackageModel

/// The bundler for creating iOS apps.
enum IOSBundler: Bundler {
  /// Bundles the built executable and resources into an iOS app.
  ///
  /// ``build(product:in:buildConfiguration:universal:)`` should usually be called first.
  /// - Parameters:
  ///   - appName: The name to give the bundled app.
  ///   - appConfiguration: The app's configuration.
  ///   - packageDirectory: The root directory of the package containing the app.
  ///   - productsDirectory: The directory containing the products from the build step.
  ///   - outputDirectory: The directory to output the app into.
  ///   - isXcodeBuild: Does nothing for iOS.
  ///   - universal: Does nothing for iOS.
  ///   - codesigningIdentity: If not `nil`, the app will be codesigned using the given identity.
  ///   - provisioningProfile: If not `nil`, this provisioning profile will get embedded in the app.
  ///   - platformVersion: The platform version to target.
  /// - Returns: If a failure occurs, it is returned.
  static func bundle(
    appName: String,
    appConfiguration: AppConfiguration,
    packageDirectory: URL,
    productsDirectory: URL,
    outputDirectory: URL,
    isXcodeBuild: Bool,
    universal: Bool,
    codesigningIdentity: String?,
    provisioningProfile: URL?,
    platformVersion: String
  ) async -> Result<Void, Error> {
    log.info("Bundling '\(appName).app'")

    let manifest: Manifest
    switch await SwiftPackageManager.loadPackageManifest(from: packageDirectory) {
      case .success(let value):
        manifest = value
      case .failure(let error):
        return .failure(IOSBundlerError.failedToLoadManifest(error))
    }

    let executableArtifact = productsDirectory.appendingPathComponent(appConfiguration.product)

    let appBundle = outputDirectory.appendingPathComponent("\(appName).app")
    let appExecutable = appBundle.appendingPathComponent(appName)
    // let appDynamicLibrariesDirectory = appBundle.appendingPathComponent("Libraries")

    // let createAppIconIfPresent: () -> Result<Void, IOSBundlerError> = {
    //   if let path = appConfiguration.icon {
    //     let icon = packageDirectory.appendingPathComponent(path)
    //     return Self.createAppIcon(icon: icon, outputDirectory: appAssets)
    //   }
    //   return .success()
    // }

    let copyResourcesBundles: () -> Result<Void, IOSBundlerError> = {
      ResourceBundler.copyResources(
        from: productsDirectory,
        to: appBundle,
        fixBundles: !isXcodeBuild && !universal,
        platform: .iOS(version: platformVersion),
        packageName: manifest.displayName,
        productName: appConfiguration.product
      ).mapError { error in
        .failedToCopyResourceBundles(error)
      }
    }

    // let copyDynamicLibraries: () -> Result<Void, IOSBundlerError> = {
    //   DynamicLibraryBundler.copyDynamicLibraries(
    //     from: productsDirectory,
    //     to: appDynamicLibrariesDirectory,
    //     appExecutable: appExecutable,
    //     isXcodeBuild: false,
    //     universal: false
    //   ).mapError { error in
    //     .failedToCopyDynamicLibraries(error)
    //   }
    // }

    let embedProfile: () -> Result<Void, IOSBundlerError> = {
      if let provisioningProfile = provisioningProfile {
        return Self.embedProvisioningProfile(provisioningProfile, in: appBundle)
      } else {
        return .success()
      }
    }

    let codesign: () -> Result<Void, IOSBundlerError> = {
      if let identity = codesigningIdentity {
        return CodeSigner.signWithGeneratedEntitlements(
          bundle: appBundle,
          identityId: identity,
          bundleIdentifier: appConfiguration.identifier
        ).mapError { error in
          return .failedToCodesign(error)
        }
      } else {
        return .success()
      }
    }

    let bundleApp = flatten(
      { Self.createAppDirectoryStructure(at: outputDirectory, appName: appName) },
      { Self.copyExecutable(at: executableArtifact, to: appExecutable) },
      { Self.createMetadataFiles(at: appBundle, appName: appName, appConfiguration: appConfiguration, iOSVersion: platformVersion) },
      // { createAppIconIfPresent() },
      { copyResourcesBundles() },
      // { copyDynamicLibraries() },
      { embedProfile() },
      { codesign() }
    )

    return bundleApp().mapError { (error: IOSBundlerError) -> Error in
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
  private static func createAppDirectoryStructure(at outputDirectory: URL, appName: String) -> Result<Void, IOSBundlerError> {
    log.info("Creating '\(appName).app'")
    let fileManager = FileManager.default

    let appBundleDirectory = outputDirectory.appendingPathComponent("\(appName).app")
    // let appDynamicLibrariesDirectory = appBundleDirectory.appendingPathComponent("Libraries")

    do {
      if fileManager.itemExists(at: appBundleDirectory, withType: .directory) {
        try fileManager.removeItem(at: appBundleDirectory)
      }
      try fileManager.createDirectory(at: appBundleDirectory)
      // TODO: support dynamic libraries on ios
      // try fileManager.createDirectory(at: appDynamicLibrariesDirectory)
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
  private static func copyExecutable(at source: URL, to destination: URL) -> Result<Void, IOSBundlerError> {
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
  ///   - iOSVersion: The iOS version to target.
  /// - Returns: If an error occurs, a failure is returned.
  private static func createMetadataFiles(
    at outputDirectory: URL,
    appName: String,
    appConfiguration: AppConfiguration,
    iOSVersion: String
  ) -> Result<Void, IOSBundlerError> {
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
      platform: .iOS(version: iOSVersion)
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
  ///            If the file is neither an `icns` or a `png`, a failure is also returned.
  private static func createAppIcon(icon: URL, outputDirectory: URL) -> Result<Void, IOSBundlerError> {
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

  private static func embedProvisioningProfile(_ provisioningProfile: URL, in bundle: URL) -> Result<Void, IOSBundlerError> {
    log.info("Embedding provisioning profile")

    do {
      try FileManager.default.copyItem(at: provisioningProfile, to: bundle.appendingPathComponent("embedded.mobileprovision"))
    } catch {
      return .failure(.failedToCopyProvisioningProfile(error))
    }

    return .success()
  }
}
