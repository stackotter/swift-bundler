import Foundation

/// The core functionality of Swift Bundler.
enum Bundler {
  /// Builds the app's executable.
  /// - Parameters:
  ///   - product: The name of the product to build.
  ///   - packageDirectory: The root directory of the package containing the product.
  ///   - buildConfiguration: The configuration to build the product with.
  ///   - architectures: The architectures to build for.
  /// - Returns: If building fails, a failure is returned.
  static func build(
    product: String,
    in packageDirectory: URL,
    buildConfiguration: SwiftPackageManager.BuildConfiguration,
    architectures: [SwiftPackageManager.Architecture]
  ) -> Result<Void, BundlerError> {
    return SwiftPackageManager.build(
      product: product,
      packageDirectory: packageDirectory,
      configuration: buildConfiguration,
      architectures: architectures
    ).mapError { error in
      .failedToBuild(product: product, error)
    }
  }
  
  /// Bundles the built executable and resources into a macOS app.
  ///
  /// ``build(product:in:buildConfiguration:universal:)`` should usually be called first.
  /// - Parameters:
  ///   - appName: The name to give the bundled app.
  ///   - appConfiguration: The app's configuration.
  ///   - packageDirectory: The root directory of the package containing the app.
  ///   - productsDirectory: The directory containing the products from the build step.
  ///   - outputDirectory: The directory to output the app into.
  ///   - isXcodeBuild: Whether the build products were created by Xcode or not.
  ///   - universal: Whether the build products were built as universal binaries or not.
  /// - Returns: If a failure occurs, it is returned.
  static func bundle(
    appName: String,
    appConfiguration: AppConfiguration,
    packageDirectory: URL,
    productsDirectory: URL,
    outputDirectory: URL,
    isXcodeBuild: Bool,
    universal: Bool
  ) -> Result<Void, BundlerError> {
    log.info("Bundling '\(appName).app'")
    let executableArtifact = productsDirectory.appendingPathComponent(appConfiguration.product)
    
    let appBundle = outputDirectory.appendingPathComponent("\(appName).app")
    let appContents = appBundle.appendingPathComponent("Contents")
    let appExecutable = appContents.appendingPathComponent("MacOS/\(appName)")
    let appResources = appContents.appendingPathComponent("Resources")
    let appDynamicLibrariesDirectory = appContents.appendingPathComponent("Libraries")

    let createAppIconIfPresent: () -> Result<Void, BundlerError> = {
      if let path = appConfiguration.icon {
        let icon = packageDirectory.appendingPathComponent(path)
        return Self.createAppIcon(icon: icon, outputDirectory: appResources)
      }
      return .success()
    }
    
    let copyResourcesBundles: () -> Result<Void, BundlerError> = {
      ResourceBundler.copyResourceBundles(
        from: productsDirectory,
        to: appResources,
        fixBundles: !isXcodeBuild && !universal,
        minimumMacOSVersion: appConfiguration.minimumMacOSVersion
      ).mapError { error in
        .failedToCopyResourceBundles(error)
      }
    }
    
    let copyDynamicLibraries: () -> Result<Void, BundlerError> = {
      DynamicLibraryBundler.copyDynamicLibraries(
        from: productsDirectory,
        to: appDynamicLibrariesDirectory,
        appExecutable: appExecutable,
        isXcodeBuild: isXcodeBuild,
        universal: universal
      ).mapError { error in
        .failedToCopyDynamicLibraries(error)
      }
    }
    
    let bundleApp = flatten(
      { Self.createAppDirectoryStructure(at: outputDirectory, appName: appName) },
      { Self.copyExecutable(at: executableArtifact, to: appExecutable) },
      { Self.createMetadataFiles(at: appContents, appName: appName, appConfiguration: appConfiguration) },
      { createAppIconIfPresent() },
      { copyResourcesBundles() },
      { copyDynamicLibraries() })
    
    return bundleApp()
  }
  
  /// Runs the app (without building or bundling first).
  /// - Parameters:
  ///   - appName: The app's name.
  ///   - outputDirectory: The output directory containing the built app.
  /// - Returns: Returns a failure if the app fails to run.
  static func run(appName: String, outputDirectory: URL) -> Result<Void, BundlerError> {
    log.info("Running '\(appName).app'")
    let appBundle = outputDirectory.appendingPathComponent("\(appName).app")
    let appExecutable = appBundle.appendingPathComponent("Contents/MacOS/\(appName)")
    let process = Process.create(appExecutable.path)
    return process.runAndWait()
      .mapError { error in
        .failedToRunExecutable(error)
      }
  }
  
  /// Gets the application support directory for Swift Bundler.
  /// - Returns: The application support directory, or a failure if the directory couldn't be found or created.
  static func getApplicationSupportDirectory() -> Result<URL, BundlerError> {
    let directory: URL
    do {
      directory = try FileManager.default.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: false
      ).appendingPathComponent("dev.stackotter.swift-bundler")
    } catch {
      return .failure(.failedToGetApplicationSupportDirectory(error))
    }
    
    do {
      try FileManager.default.createDirectory(at: directory)
    } catch {
      return .failure(.failedToCreateApplicationSupportDirectory(error))
    }
    
    return .success(directory)
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
  private static func createAppDirectoryStructure(at outputDirectory: URL, appName: String) -> Result<Void, BundlerError> {
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
  private static func copyExecutable(at source: URL, to destination: URL) -> Result<Void, BundlerError> {
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
  /// - Returns: If an error occurs, a failure is returned.
  private static func createMetadataFiles(at outputDirectory: URL, appName: String, appConfiguration: AppConfiguration) -> Result<Void, BundlerError> {
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
      version: appConfiguration.version,
      bundleIdentifier: appConfiguration.bundleIdentifier,
      category: appConfiguration.category,
      minimumMacOSVersion: appConfiguration.minimumMacOSVersion,
      extraPlistEntries: appConfiguration.extraPlistEntries
    ).mapError { error in
      .failedToCreateInfoPlist(error)
    }
  }
  
  /// Copies an `icns` to the output directory if provided. Alternatively, it creates the app's `AppIcon.icns` from a png.
  ///
  /// `AppIcon.icns` takes precendence over `Icon1024x1024.png`.
  /// - Parameters:
  ///   - icon: The app's icon. Should be either an `icns` file or a 1024x1024 png with an alpha channel. The png is not validated for those properties.
  ///   - outputDirectory: Should be the app's `Resources` directory.
  /// - Returns: If the png exists and there is an error while converting it to `icns`, a failure is returned. If the file is neither an `icns` or a `png`, a failure is also returned.
  private static func createAppIcon(icon: URL, outputDirectory: URL) -> Result<Void, BundlerError> {
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
