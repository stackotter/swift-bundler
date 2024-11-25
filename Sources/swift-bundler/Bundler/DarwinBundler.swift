import Foundation

/// The bundler for creating macOS apps.
enum DarwinBundler: Bundler {
  struct Context {
    /// Whether the build products were created by Xcode or not.
    var isXcodeBuild: Bool
    /// Whether the build products were built as universal binaries or not.
    var universal: Bool
    /// If `true`, the app bundle will not depend on any system-wide dependencies
    /// stalled (such as gtk).
    var standAlone: Bool
    /// The platform that the app should be bundled for.
    var platform: ApplePlatform
    /// The platform version that the executable was built for.
    var platformVersion: String
    /// The code signing context if code signing has been requested.
    var codeSigningContext: CodeSigningContext?

    struct CodeSigningContext {
      /// The identity to sign the app with.
      var identity: String
      /// A file containing entitlements to give the app if codesigning.
      var entitlements: URL?
      /// If not `nil`, this provisioning profile will get embedded in the app.
      var provisioningProfile: URL?
    }
  }

  static func bundle(
    _ context: BundlerContext,
    _ additionalContext: Context
  ) -> Result<Void, DarwinBundlerError> {
    log.info("Bundling '\(context.appName).app'")

    let appBundle = context.outputDirectory.appendingPathComponent("\(context.appName).app")
    let bundleStructure = DarwinAppBundleStructure(
      at: appBundle,
      platform: additionalContext.platform
    )
    let appExecutable = bundleStructure.executableDirectory.appendingPathComponent(context.appName)

    let removeExistingAppBundle: () -> Result<Void, DarwinBundlerError> = {
      if FileManager.default.itemExists(at: appBundle, withType: .directory) {
        do {
          try FileManager.default.removeItem(at: appBundle)
        } catch {
          return .failure(.failedToRemoveExistingAppBundle(bundle: appBundle, error))
        }
      }
      return .success()
    }

    let createAppIconIfPresent: () -> Result<Void, DarwinBundlerError> = {
      if let path = context.appConfiguration.icon {
        let icon = URL(fileURLWithPath: path)
        return Self.compileAppIcon(at: icon, to: bundleStructure.appIconFile)
      }
      return .success()
    }

    let copyResourcesBundles: () -> Result<Void, DarwinBundlerError> = {
      ResourceBundler.copyResources(
        from: context.productsDirectory,
        to: bundleStructure.resourcesDirectory,
        fixBundles: !additionalContext.isXcodeBuild && !additionalContext.universal,
        platform: context.platform,
        platformVersion: additionalContext.platformVersion,
        packageName: context.packageName,
        productName: context.appConfiguration.product
      ).mapError { error in
        .failedToCopyResourceBundles(error)
      }
    }

    let copyDynamicLibraries: () -> Result<Void, DarwinBundlerError> = {
      DynamicLibraryBundler.copyDynamicLibraries(
        dependedOnBy: appExecutable,
        to: bundleStructure.librariesDirectory,
        productsDirectory: context.productsDirectory,
        isXcodeBuild: additionalContext.isXcodeBuild,
        universal: additionalContext.universal,
        makeStandAlone: additionalContext.standAlone
      ).mapError { error in
        .failedToCopyDynamicLibraries(error)
      }
    }

    let embedProfile: () -> Result<Void, DarwinBundlerError> = {
      guard
        let provisioningProfile = additionalContext.codeSigningContext?.provisioningProfile
      else {
        return .success()
      }
      return Self.embedProvisioningProfile(provisioningProfile, in: appBundle)
    }

    let sign: () -> Result<Void, DarwinBundlerError> = {
      if let codeSigningContext = additionalContext.codeSigningContext {
        return CodeSigner.signAppBundle(
          bundle: appBundle,
          identityId: codeSigningContext.identity,
          entitlements: codeSigningContext.entitlements
        ).mapError { error in
          return .failedToCodesign(error)
        }
      } else {
        return .success()
      }
    }

    let bundleApp = flatten(
      removeExistingAppBundle,
      bundleStructure.createDirectories,
      { Self.copyExecutable(at: context.executableArtifact, to: appExecutable) },
      { Self.createPkgInfoFile(at: bundleStructure.pkgInfoFile) },
      {
        Self.createInfoPlistFile(
          at: bundleStructure.infoPlistFile,
          appName: context.appName,
          appConfiguration: context.appConfiguration,
          platform: additionalContext.platform,
          platformVersion: additionalContext.platformVersion
        )
      },
      createAppIconIfPresent,
      copyResourcesBundles,
      copyDynamicLibraries,
      embedProfile,
      sign
    )

    return bundleApp()
  }

  // MARK: Private methods

  /// Copies the built executable into the app bundle.
  /// - Parameters:
  ///   - source: The location of the built executable.
  ///   - destination: The target location of the built executable (the file not the directory).
  /// - Returns: If an error occurs, a failure is returned.
  private static func copyExecutable(
    at source: URL, to destination: URL
  ) -> Result<Void, DarwinBundlerError> {
    log.info("Copying executable")
    do {
      try FileManager.default.copyItem(at: source, to: destination)
      return .success()
    } catch {
      return .failure(.failedToCopyExecutable(source: source, destination: destination, error))
    }
  }

  /// Create's a `PkgInfo` file.
  /// - Parameters:
  ///   - pkgInfoFile: the location of the output `PkgInfo` file (needn't exist yet).
  /// - Returns: If an error occurs, a failure is returned.
  private static func createPkgInfoFile(at pkgInfoFile: URL) -> Result<Void, DarwinBundlerError> {
    log.info("Creating 'PkgInfo'")
    do {
      var pkgInfoBytes: [UInt8] = [0x41, 0x50, 0x50, 0x4c, 0x3f, 0x3f, 0x3f, 0x3f]
      let pkgInfoData = Data(bytes: &pkgInfoBytes, count: pkgInfoBytes.count)
      try pkgInfoData.write(to: pkgInfoFile)
      return .success()
    } catch {
      return .failure(.failedToCreatePkgInfo(file: pkgInfoFile, error))
    }
  }

  /// Creates an app's `Info.plist` file.
  /// - Parameters:
  ///   - infoPlistFile: The output `Info.plist` file (needn't exist yet).
  ///   - appName: The app's name.
  ///   - appConfiguration: The app's configuration.
  ///   - macOSVersion: The macOS version to target.
  /// - Returns: If an error occurs, a failure is returned.
  private static func createInfoPlistFile(
    at infoPlistFile: URL,
    appName: String,
    appConfiguration: AppConfiguration,
    platform: ApplePlatform,
    platformVersion: String
  ) -> Result<Void, DarwinBundlerError> {
    log.info("Creating 'Info.plist'")
    return PlistCreator.createAppInfoPlist(
      at: infoPlistFile,
      appName: appName,
      configuration: appConfiguration,
      platform: platform.platform,
      platformVersion: platformVersion
    ).mapError { error in
      .failedToCreateInfoPlist(error)
    }
  }

  /// If given an `icns`, the `icns` gets copied to the output file. If given a `png`, an `icns` is created from the `png`.
  ///
  /// The files are not validated any further than checking their file extensions.
  /// - Parameters:
  ///   - inputIconFile: The app's icon. Should be either an `icns` file or a 1024x1024 `png` with an alpha channel.
  ///   - outputIconFile: The `icns` file to output to.
  /// - Returns: If the png exists and there is an error while converting it to `icns`, a failure is returned.
  ///   If the file is neither an `icns` or a `png`, a failure is also returned.
  private static func compileAppIcon(
    at inputIconFile: URL,
    to outputIconFile: URL
  ) -> Result<Void, DarwinBundlerError> {
    // Copy `AppIcon.icns` if present
    if inputIconFile.pathExtension == "icns" {
      log.info("Copying '\(inputIconFile.lastPathComponent)'")
      do {
        try FileManager.default.copyItem(at: inputIconFile, to: outputIconFile)
        return .success()
      } catch {
        return .failure(
          .failedToCopyICNS(source: inputIconFile, destination: outputIconFile, error)
        )
      }
    } else if inputIconFile.pathExtension == "png" {
      log.info(
        "Creating '\(outputIconFile.lastPathComponent)' from '\(inputIconFile.lastPathComponent)'"
      )
      return IconSetCreator.createIcns(from: inputIconFile, outputFile: outputIconFile)
        .mapError { error in
          .failedToCreateIcon(error)
        }
    }

    return .failure(.invalidAppIconFile(inputIconFile))
  }

  private static func embedProvisioningProfile(
    _ provisioningProfile: URL,
    in bundle: URL
  ) -> Result<Void, DarwinBundlerError> {
    log.info("Embedding provisioning profile")

    do {
      try FileManager.default.copyItem(
        at: provisioningProfile,
        to: bundle.appendingPathComponent("embedded.mobileprovision")
      )
    } catch {
      return .failure(.failedToCopyProvisioningProfile(error))
    }

    return .success()
  }
}
