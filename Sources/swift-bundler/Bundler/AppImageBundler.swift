import Foundation

/// The bundler for creating Linux AppImage's.
enum AppImageBundler: Bundler {
  typealias Context = Void

  static func bundle(
    _ context: BundlerContext,
    _ additionalContext: Context
  ) -> Result<Void, AppImageBundlerError> {
    log.info("Bundling '\(context.appName).AppImage'")

    let executableArtifact = context.productsDirectory.appendingPathComponent(
      context.appConfiguration.product)

    let appDir = context.outputDirectory.appendingPathComponent("\(context.appName).AppDir")
    let appExecutable = appDir.appendingPathComponent("usr/bin/\(context.appName)")
    let appIconDirectory = appDir.appendingPathComponent("usr/share/icons/hicolor/1024x1024/apps")

    let copyAppIconIfPresent: () -> Result<Void, AppImageBundlerError> = {
      let destination = appIconDirectory.appendingPathComponent("\(context.appName).png")
      guard let path = context.appConfiguration.icon else {
        // TODO: Synthesize the icon a bit smarter (e.g. maybe an svg would be better to synthesize)
        FileManager.default.createFile(atPath: destination.path, contents: nil)
        return .success()
      }

      let icon = context.packageDirectory.appendingPathComponent(path)
      do {
        try FileManager.default.copyItem(at: icon, to: destination)
      } catch {
        return .failure(.failedToCopyIcon(source: icon, destination: destination, error))
      }
      return .success()
    }

    let bundleApp = flatten(
      { Self.createAppDirectoryStructure(at: context.outputDirectory, appName: context.appName) },
      { Self.copyExecutable(at: executableArtifact, to: appExecutable) },
      {
        Self.createDesktopFile(
          at: appDir,
          appName: context.appName,
          appConfiguration: context.appConfiguration
        )
      },
      copyAppIconIfPresent,
      { Self.createSymlinks(at: appDir, appName: context.appName) },
      {
        log.info("Converting '\(context.appName).AppDir' to '\(context.appName).AppImage'")
        return AppImageTool.bundle(appDir: appDir)
          .mapError { .failedToBundleAppDir($0) }
      }
    )

    return bundleApp()
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
