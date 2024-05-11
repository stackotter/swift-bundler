import Foundation

/// The bundler for creating Linux AppImage's.
enum AppImageBundler: Bundler {
  /// Bundles the built executable and resources into a Linux AppImage.
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
  ///   - targetingSimulator: Does nothing for Linux builds.
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
    codesigningEntitlements: URL?,
    provisioningProfile: URL?,
    platformVersion: String,
    targetingSimulator: Bool
  ) -> Result<Void, Error> {
    log.info("Bundling '\(appName).AppImage'")

    let executableArtifact = productsDirectory.appendingPathComponent(appConfiguration.product)

    let appDir = outputDirectory.appendingPathComponent("\(appName).AppDir")
    let appExecutable = appDir.appendingPathComponent("usr/bin/\(appName)")
    let appIconDirectory = appDir.appendingPathComponent("usr/share/icons/hicolor/1024x1024/apps")

    let copyAppIconIfPresent: () -> Result<Void, AppImageBundlerError> = {
      let destination = appIconDirectory.appendingPathComponent("\(appName).png")
      guard let path = appConfiguration.icon else {
        // TODO: Synthesize the icon a bit smarter (e.g. maybe an svg would be better to synthesize)
        FileManager.default.createFile(atPath: destination.path, contents: nil)
        return .success()
      }

      let icon = packageDirectory.appendingPathComponent(path)
      do {
        try FileManager.default.copyItem(at: icon, to: destination)
      } catch {
        return .failure(.failedToCopyIcon(source: icon, destination: destination, error))
      }
      return .success()
    }

    let bundleApp = flatten(
      { Self.createAppDirectoryStructure(at: outputDirectory, appName: appName) },
      { Self.copyExecutable(at: executableArtifact, to: appExecutable) },
      {
        Self.createDesktopFile(
          at: appDir,
          appName: appName,
          appConfiguration: appConfiguration
        )
      },
      copyAppIconIfPresent,
      { Self.createSymlinks(at: appDir, appName: appName) },
      {
        log.info("Converting '\(appName).AppDir' to '\(appName).AppImage'")
        return AppImageTool.bundle(appDir: appDir)
          .mapError { .failedToBundleAppDir($0) }
      }
    )

    return bundleApp().intoAnyError()
  }

  // MARK: Private methods

  /// Creates the directory structure for an app.
  ///
  /// Creates the following structure:
  /// - `AppName.AppDir`
  ///   - `usr`
  ///     - `bin`
  ///     - `share/icons/hicolor/1024x1024/apps`
  ///
  /// If the app directory already exists, it is deleted before continuing.
  /// - Parameters:
  ///   - outputDirectory: The directory to output the app to.
  ///   - appName: The name of the app.
  /// - Returns: A failure if directory creation fails.
  private static func createAppDirectoryStructure(
    at outputDirectory: URL, appName: String
  )
    -> Result<Void, AppImageBundlerError>
  {
    log.info("Creating '\(appName).AppDir'")
    let fileManager = FileManager.default

    // TODO: Save these paths into an `AppDir` struct or something so that they don't have to
    // get computed separately in `AppImageBundler.bundle`, same goes for the other
    // bundlers.
    let appDir = outputDirectory.appendingPathComponent("\(appName).AppDir")
    let binDir = appDir.appendingPathComponent("usr/bin")
    let iconDir = appDir.appendingPathComponent("usr/share/icons/hicolor/1024x1024/apps")

    do {
      if fileManager.itemExists(at: appDir, withType: .directory) {
        try fileManager.removeItem(at: appDir)
      }
      try fileManager.createDirectory(at: binDir)
      try fileManager.createDirectory(at: iconDir)
      return .success()
    } catch {
      return .failure(
        .failedToCreateAppDirSkeleton(directory: appDir, error)
      )
    }
  }

  /// Copies the built executable into the app bundle.
  /// - Parameters:
  ///   - source: The location of the built executable.
  ///   - destination: The target location of the built executable (the file not the directory).
  /// - Returns: If an error occus, a failure is returned.
  private static func copyExecutable(
    at source: URL, to destination: URL
  ) -> Result<
    Void, AppImageBundlerError
  > {
    log.info("Copying executable")
    do {
      try FileManager.default.copyItem(at: source, to: destination)
      return .success()
    } catch {
      return .failure(.failedToCopyExecutable(source: source, destination: destination, error))
    }
  }

  /// Creates an app's `.desktop` file.
  /// - Parameters:
  ///   - outputDirectory: Should be the app's `Contents` directory.
  ///   - appName: The app's name.
  ///   - appConfiguration: The app's configuration.
  /// - Returns: If an error occurs, a failure is returned.
  private static func createDesktopFile(
    at outputDirectory: URL,
    appName: String,
    appConfiguration: AppConfiguration
  ) -> Result<Void, AppImageBundlerError> {
    log.info("Creating '\(appName).desktop'")
    let desktopFile = outputDirectory.appendingPathComponent("\(appName).desktop")
    let properties = [
      ("Type", "Application"),
      ("Version", "1.0"),
      ("Name", appName),
      ("Comment", ""),
      ("Exec", "\(appName) %F"),
      ("Icon", appName),
      ("Terminal", "false"),
      ("Categories", ""),
    ]

    let contents =
      "[Desktop Entry]\n"
      + properties.map { "\($0)=\($1)" }.joined(separator: "\n")

    guard let data = contents.data(using: .utf8) else {
      return .failure(.failedToCreateDesktopFile(desktopFile, nil))
    }

    do {
      try data.write(to: desktopFile)
    } catch {
      return .failure(.failedToCreateDesktopFile(desktopFile, error))
    }

    return .success()
  }

  /// Creates symlinks to complete the required AppDir structure.
  /// - Parameters:
  ///   - appDir: The root of the AppDir.
  ///   - appName: The app's name.
  private static func createSymlinks(
    at appDir: URL,
    appName: String
  ) -> Result<Void, AppImageBundlerError> {
    let icon = appDir.appendingPathComponent(
      "usr/share/icons/hicolor/1024x1024/apps/\(appName).png"
    )

    // Create `.DirIcon` and `AppName.png` if an icon is present.
    var operation: () -> Result<Void, AppImageBundlerError> = { .success() }
    if FileManager.default.fileExists(atPath: icon.path) {
      operation = flatten(
        operation,
        {
          Self.createSymlink(
            at: appDir.appendingPathComponent("\(appName).png"),
            withDestination: icon
          )
        },
        {
          Self.createSymlink(
            at: appDir.appendingPathComponent(".DirIcon"),
            withDestination: appDir.appendingPathComponent("\(appName).png")
          )
        }
      )
    }

    // Create `AppRun` pointing to executable
    operation = flatten(
      operation,
      {
        Self.createSymlink(
          at: appDir.appendingPathComponent("AppRun"),
          withDestination: appDir.appendingPathComponent("usr/bin/\(appName)")
        )
      }
    )

    return operation()
  }

  private static func createSymlink(
    at symlink: URL,
    withDestination destination: URL
  ) -> Result<Void, AppImageBundlerError> {
    do {
      try FileManager.default.createSymbolicLink(
        at: symlink,
        withDestinationURL: destination
      )
    } catch {
      return .failure(.failedToCreateSymlink(source: symlink, destination: destination, error))
    }

    return .success()
  }
}
