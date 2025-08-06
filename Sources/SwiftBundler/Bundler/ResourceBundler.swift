import Foundation

/// A utility for handling resource bundles.
enum ResourceBundler {
  /// Compiles an `xcassets` directory into an `Assets.car` file.
  /// - Parameters:
  ///   - assetCatalog: The catalog to compile.
  ///   - destinationDirectory: The directory to output `Assets.car` to.
  ///   - platform: The platform to compile for.
  ///   - platformVersion: The platform version to target.
  ///   - keepSource: If `false`, the catalog will be deleted after compilation.
  /// - Returns: A failure if an error occurs.
  static func compileAssetCatalog(
    _ assetCatalog: URL,
    to destinationDirectory: URL,
    for platform: Platform,
    platformVersion: String,
    keepSource: Bool = true
  ) async throws(Error) {
    // TODO: Move to an AssetCatalogCompiler
    log.info("Compiling asset catalog")
    try await Error.catch(withMessage: .failedToCompileXCAssets) {
      try await Process.create(
        "/usr/bin/xcrun",
        arguments: [
          "actool", assetCatalog.path,
          "--compile", destinationDirectory.path,
          "--platform", platform.sdkName,
          "--minimum-deployment-target", platformVersion,
        ]
      ).runAndWait()
    }

    if !keepSource {
      try FileManager.default.removeItem(
        at: assetCatalog,
        errorMessage: ErrorMessage.failedToDeleteAssetCatalog
      )
    }
  }

  /// Copies the resource bundles present in a source directory into a
  /// destination directory. If the bundles were built by SwiftPM, they will get
  /// fixed up to be consistent with bundles built by Xcode.
  /// - Parameters:
  ///   - sourceDirectory: The directory containing generated bundles.
  ///   - destinationDirectory: The directory to copy the bundles to, fixing them if required.
  ///   - fixBundles: If `false`, bundles will be left alone when copying them.
  ///   - platform: The platform that the app should run on.
  ///   - platformVersion: The minimum platform version that the app should run on.
  ///   - packageName: The name of the package this app is in.
  ///   - mainProductName: The name of the app's product.
  static func copyResources(
    from sourceDirectory: URL,
    to destinationDirectory: URL,
    fixBundles: Bool,
    platform: Platform,
    platformVersion: String,
    packageName: String,
    productName: String
  ) async throws(Error) {
    let contents = try FileManager.default.contentsOfDirectory(
      at: sourceDirectory,
      errorMessage: ErrorMessage.failedToEnumerateBundles
    )

    let mainBundleName = "\(packageName)_\(productName)"
    for file in contents where file.pathExtension == "bundle" {
      guard file.exists(withType: .directory) else {
        continue
      }

      if !fixBundles {
        try copyResourceBundle(
          file,
          to: destinationDirectory
        )
      } else {
        let bundleName = file.deletingPathExtension().lastPathComponent
        try await fixAndCopyResourceBundle(
          file,
          to: destinationDirectory,
          platform: platform,
          platformVersion: platformVersion,
          isMainBundle: bundleName == mainBundleName
        )
      }
    }
  }

  /// Copies the specified resource bundle into a destination directory.
  /// - Parameters:
  ///   - bundle: The bundle to copy.
  ///   - destination: The directory to copy the bundle to.
  static func copyResourceBundle(
    _ bundle: URL,
    to destination: URL
  ) throws(Error) {
    log.info("Copying resource bundle '\(bundle.lastPathComponent)'")
    try FileManager.default.copyItem(
      at: bundle,
      to: destination / bundle.lastPathComponent,
      errorMessage: ErrorMessage.failedToCopyBundle
    )
  }

  /// Copies the specified resource bundle into a destination directory. Before
  /// copying, the bundle is fixed up to be consistent with bundles built by
  /// Xcode.
  ///
  /// Creates the proper bundle structure, adds an `Info.plist` and compiles any
  /// metal shaders present in the bundle.
  /// - Parameters:
  ///   - bundle: The bundle to fix and copy.
  ///   - destination: The directory to copy the bundle to.
  ///   - platform: The platform that the app should run on.
  ///   - platformVersion: The minimum platform version that the app should run on.
  ///   - isMainBundle: If `true`, the contents of the bundle are fixed and copied
  ///     straight into the app's resources directory.
  static func fixAndCopyResourceBundle(
    _ bundle: URL,
    to destination: URL,
    platform: Platform,
    platformVersion: String,
    isMainBundle: Bool
  ) async throws(Error) {
    log.info("Compiling and copying resource bundle '\(bundle.lastPathComponent)'")

    let destinationBundle: URL
    let destinationBundleResources: URL
    if isMainBundle {
      destinationBundle = destination
      destinationBundleResources = destinationBundle
    } else {
      destinationBundle = destination.appendingPathComponent(bundle.lastPathComponent)

      switch platform {
        case .macOS:
          destinationBundleResources = destinationBundle.appendingPathComponent(
            "Contents/Resources"
          )
        case .iOS, .iOSSimulator, .visionOS, .visionOSSimulator, .tvOS, .tvOSSimulator:
          destinationBundleResources = destinationBundle
        case .linux, .windows:
          // TODO: Implement on Linux and Windows if neccessary
          fatalError("TODO: Implement resource bundle fixing for linux and Windows")
      }
    }

    let assetCatalog = destinationBundleResources.appendingPathComponent("Assets.xcassets")
    let assetCatalogExists = assetCatalog.exists(withType: .directory)

    if !isMainBundle {
      // All resource bundles other than the main one get put in separate
      // resource bundles (whereas the main resources just get put in the root
      // of the resources directory).
      try createResourceBundleDirectoryStructure(at: destinationBundle, for: platform)
      try createResourceBundleInfoPlist(
        in: destinationBundle,
        platform: platform,
        platformVersion: platformVersion
      )
    }

    try copyResources(from: bundle, to: destinationBundleResources)

    if assetCatalogExists {
      // Compile asset catalog if present
      try await compileAssetCatalog(
        assetCatalog,
        to: destinationBundleResources,
        for: platform,
        platformVersion: platformVersion,
        keepSource: false
      )
    }

    // Copile metal shaders
    try await Error.catch(withMessage: .failedToCompileMetalShaders) {
      try await MetalCompiler.compileMetalShaders(
        in: destinationBundleResources,
        for: platform,
        platformVersion: platformVersion,
        keepSources: false
      )
    }

    // Compile storyboards
    try await Error.catch(withMessage: .failedToCompileStoryboards) {
      try await StoryboardCompiler.compileStoryboards(
        in: destinationBundleResources,
        to: destinationBundleResources.appendingPathComponent("Base.lproj"),
        keepSources: false
      )
    }

    // Compile string catalogs
    try Error.catch(withMessage: .failedToCompileStringsCatalogs) {
      try StringCatalogCompiler.compileStringCatalogs(
        in: destinationBundleResources,
        to: destinationBundleResources,
        keepSources: false
      )
    }
  }

  // MARK: Private methods

  /// Creates the directory structure for the specified resource bundle directory.
  ///
  /// The structure created is as follows:
  ///
  /// ```txt
  /// - `Contents`
  ///   - `Resources`
  /// ```
  ///
  /// - Parameter bundle: The bundle to create.
  private static func createResourceBundleDirectoryStructure(
    at bundle: URL,
    for platform: Platform
  ) throws(Error) {
    let directory: URL
    switch platform {
      case .macOS:
        let bundleContents = bundle.appendingPathComponent("Contents")
        let bundleResources = bundleContents.appendingPathComponent("Resources")
        directory = bundleResources
      case .iOS, .iOSSimulator, .visionOS, .visionOSSimulator, .tvOS, .tvOSSimulator:
        directory = bundle
      case .linux, .windows:
        // TODO: Implement for linux
        fatalError("TODO: Implement resource bundle fixing on Linux and Windows")
    }

    try FileManager.default.createDirectory(
      at: directory,
      errorMessage: ErrorMessage.failedToCreateBundleDirectory
    )
  }

  /// Creates the `Info.plist` file for a resource bundle.
  /// - Parameters:
  ///   - bundle: The bundle to create the `Info.plist` file for.
  ///   - platform: The platform that the app should run on.
  ///   - platformVersion: The platform version to target.
  /// - Returns: If an error occurs, a failure is returned.
  private static func createResourceBundleInfoPlist(
    in bundle: URL,
    platform: Platform,
    platformVersion: String
  ) throws(Error) {
    let bundleName = bundle.deletingPathExtension().lastPathComponent

    let infoPlist: URL
    switch platform {
      case .macOS:
        infoPlist =
          bundle
          .appendingPathComponent("Contents")
          .appendingPathComponent("Info.plist")
      case .iOS, .iOSSimulator, .visionOS, .visionOSSimulator, .tvOS, .tvOSSimulator:
        infoPlist =
          bundle
          .appendingPathComponent("Info.plist")
      case .linux, .windows:
        // TODO: Implement for Linux and Windows
        fatalError("Implement for Linux and Windows")
    }

    do {
      try PlistCreator.createResourceBundleInfoPlist(
        at: infoPlist,
        bundleName: bundleName,
        platform: platform,
        platformVersion: platformVersion
      )
    } catch {
      throw Error(.failedToCreateInfoPlist(file: infoPlist), cause: error)
    }
  }

  /// Copies the resources from a source directory to a destination directory.
  /// - Parameters:
  ///   - source: The source directory.
  ///   - destination: The destination directory.
  private static func copyResources(
    from source: URL,
    to destination: URL
  ) throws(Error) {
    let contents = try FileManager.default.contentsOfDirectory(
      at: source,
      errorMessage: ErrorMessage.failedToEnumerateBundleContents
    )

    for file in contents {
      let fileDestination = destination / file.lastPathComponent
      try FileManager.default.copyItem(
        at: file,
        to: fileDestination,
        errorMessage: ErrorMessage.failedToCopyResource
      )
    }
  }
}
