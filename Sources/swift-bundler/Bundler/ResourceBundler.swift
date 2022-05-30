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
  ) -> Result<Void, ResourceBundlerError> {
    // TODO: Move to an AssetCatalogCompiler
    log.info("Compiling asset catalog")
    return Process.create(
      "/usr/bin/xcrun",
      arguments: [
        "actool", assetCatalog.path,
        "--compile", destinationDirectory.path,
        "--platform", platform.sdkName,
        "--minimum-deployment-target", platformVersion
      ]
    ).runAndWait().mapError { error in
      return .failedToCompileXCAssets(error)
    }.flatMap { _ in
      do {
        try FileManager.default.removeItem(at: assetCatalog)
      } catch {
        return .failure(.failedToDeleteAssetCatalog(error))
      }

      return .success()
    }
  }

  /// Copies the resource bundles present in a source directory into a destination directory. If the bundles
  /// were built by SwiftPM, they will get fixed up to be consistent with bundles built by Xcode.
  /// - Parameters:
  ///   - sourceDirectory: The directory containing generated bundles.
  ///   - destinationDirectory: The directory to copy the bundles to, fixing them if required.
  ///   - fixBundles: If `false`, bundles will be left alone when copying them.
  ///   - platform: The platform that the app should run on.
  ///   - platformVersion: The minimum platform version that the app should run on.
  ///   - packageName: The name of the package this app is in.
  ///   - mainProductName: The name of the app's product.
  /// - Returns: If an error occurs, a failure is returned.
  static func copyResources(
    from sourceDirectory: URL,
    to destinationDirectory: URL,
    fixBundles: Bool,
    platform: Platform,
    platformVersion: String,
    packageName: String,
    productName: String
  ) -> Result<Void, ResourceBundlerError> {
    let contents: [URL]
    do {
      contents = try FileManager.default.contentsOfDirectory(at: sourceDirectory, includingPropertiesForKeys: nil, options: [])
    } catch {
      return .failure(.failedToEnumerateBundles(directory: sourceDirectory, error))
    }

    let mainBundleName = "\(packageName)_\(productName)"

    for file in contents where file.pathExtension == "bundle" {
      guard FileManager.default.itemExists(at: file, withType: .directory) else {
        continue
      }

      let result: Result<Void, ResourceBundlerError>
      if !fixBundles {
        result = copyResourceBundle(
          file,
          to: destinationDirectory
        )
      } else {
        let bundleName = file.deletingPathExtension().lastPathComponent
        result = fixAndCopyResourceBundle(
          file,
          to: destinationDirectory,
          platform: platform,
          platformVersion: platformVersion,
          isMainBundle: bundleName == mainBundleName
        )
      }

      if case .failure = result {
        return result
      }
    }

    return .success()
  }

  /// Copies the specified resource bundle into a destination directory.
  /// - Parameters:
  ///   - bundle: The bundle to copy.
  ///   - destination: The directory to copy the bundle to.
  /// - Returns: If an error occurs, a failure is returned.
  static func copyResourceBundle(_ bundle: URL, to destination: URL) -> Result<Void, ResourceBundlerError> {
    log.info("Copying resource bundle '\(bundle.lastPathComponent)'")

    let destinationBundle = destination.appendingPathComponent(bundle.lastPathComponent)

    do {
      try FileManager.default.copyItem(at: bundle, to: destinationBundle)
    } catch {
      return .failure(.failedToCopyBundle(source: bundle, destination: destinationBundle, error))
    }

    return .success()
  }

  /// Copies the specified resource bundle into a destination directory. Before copying, the bundle
  /// is fixed up to be consistent with bundles built by Xcode.
  ///
  /// Creates the proper bundle structure, adds an `Info.plist` and compiles any metal shaders present in the bundle.
  /// - Parameters:
  ///   - bundle: The bundle to fix and copy.
  ///   - destination: The directory to copy the bundle to.
  ///   - platform: The platform that the app should run on.
  ///   - platformVersion: The minimum platform version that the app should run on.
  ///   - isMainBundle: If `true`, the contents of the bundle are fixed and copied straight into the app's resources directory.
  /// - Returns: If an error occurs, a failure is returned.
  static func fixAndCopyResourceBundle(
    _ bundle: URL,
    to destination: URL,
    platform: Platform,
    platformVersion: String,
    isMainBundle: Bool
  ) -> Result<Void, ResourceBundlerError> {
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
          destinationBundleResources = destinationBundle.appendingPathComponent("Contents/Resources")
        case .iOS, .iOSSimulator:
          destinationBundleResources = destinationBundle
      }
    }

    let compileAssetCatalog: () -> Result<Void, ResourceBundlerError> = {
      let assetCatalog = destinationBundleResources.appendingPathComponent("Assets.xcassets")
      guard FileManager.default.itemExists(at: assetCatalog, withType: .directory) else {
        return .success()
      }

      return Self.compileAssetCatalog(
        assetCatalog,
        to: destinationBundleResources,
        for: platform,
        platformVersion: platformVersion,
        keepSource: false
      )
    }

    let compileMetalShaders: () -> Result<Void, ResourceBundlerError> = {
      return MetalCompiler.compileMetalShaders(
        in: destinationBundleResources,
        for: platform,
        keepSources: false
      ).mapError { error in
        return .failedToCompileMetalShaders(error)
      }
    }

    let compileStoryboards: () -> Result<Void, ResourceBundlerError> = {
      return StoryboardCompiler.compileStoryboards(
        in: destinationBundleResources,
        to: destinationBundleResources.appendingPathComponent("Base.lproj"),
        keepSources: false
      ).mapError { error in
        return .failedToCompileStoryboards(error)
      }
    }

    // The bundle was generated by SwiftPM, so it's gonna need a bit of fixing
    let copyBundle = flatten(
      {
        if !isMainBundle {
          return createResourceBundleDirectoryStructure(at: destinationBundle, for: platform).flatMap { _ in
            createResourceBundleInfoPlist(
              in: destinationBundle,
              platform: platform,
              platformVersion: platformVersion
            )
          }
        }
        return .success()
      },
      { copyResources(from: bundle, to: destinationBundleResources) },
      { compileAssetCatalog() },
      { compileMetalShaders() },
      { compileStoryboards() }
    )

    return copyBundle()
  }

  // MARK: Private methods

  /// Creates the directory structure for the specified resource bundle directory.
  ///
  /// The structure created is as follows:
  ///
  /// - `Contents`
  ///   - `Resources`
  ///
  /// - Parameter bundle: The bundle to create.
  /// - Returns: If an error occurs, a failure is returned.
  private static func createResourceBundleDirectoryStructure(at bundle: URL, for platform: Platform) -> Result<Void, ResourceBundlerError> {
    let directory: URL
    switch platform {
      case .macOS:
        let bundleContents = bundle.appendingPathComponent("Contents")
        let bundleResources = bundleContents.appendingPathComponent("Resources")
        directory = bundleResources
      case .iOS, .iOSSimulator:
        directory = bundle
    }

    do {
      try FileManager.default.createDirectory(at: directory)
    } catch {
      return .failure(.failedToCreateBundleDirectory(bundle, error))
    }

    return .success()
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
  ) -> Result<Void, ResourceBundlerError> {
    let bundleName = bundle.deletingPathExtension().lastPathComponent

    let infoPlist: URL
    switch platform {
      case .macOS:
        infoPlist = bundle
          .appendingPathComponent("Contents")
          .appendingPathComponent("Info.plist")
      case .iOS, .iOSSimulator:
        infoPlist = bundle
          .appendingPathComponent("Info.plist")
    }

    let result = PlistCreator.createResourceBundleInfoPlist(
      at: infoPlist,
      bundleName: bundleName,
      platform: platform,
      platformVersion: platformVersion
    )

    if case let .failure(error) = result {
      return .failure(.failedToCreateInfoPlist(file: infoPlist, error))
    }

    return .success()
  }

  /// Copies the resources from a source directory to a destination directory.
  ///
  /// If any of the resources are metal shader sources, they get compiled into a `default.metallib`.
  /// After compilation, the sources are deleted.
  /// - Parameters:
  ///   - source: The source directory.
  ///   - destination: The destination directory.
  /// - Returns: If an error occurs, a failure is returned.
  private static func copyResources(from source: URL, to destination: URL) -> Result<Void, ResourceBundlerError> {
    let contents: [URL]
    do {
      contents = try FileManager.default.contentsOfDirectory(at: source, includingPropertiesForKeys: nil, options: [])
    } catch {
      return .failure(.failedToEnumerateBundleContents(directory: source, error))
    }

    for file in contents {
      let fileDestination = destination.appendingPathComponent(file.lastPathComponent)
      do {
        try FileManager.default.copyItem(
          at: file,
          to: fileDestination)
      } catch {
        return .failure(.failedToCopyResource(source: file, destination: fileDestination, error))
      }
    }

    return .success()
  }
}
