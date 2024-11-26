import Foundation
import Parsing

/// The bundler for creating Linux AppImage's.
enum AppImageBundler: Bundler {
  typealias Context = Void

  /// A parser for the output of ldd. Parses a single line.
  private static let lddLineParser = Parse {
    PrefixThrough(" => ")
    PrefixUpTo(" (")
    Rest<Substring>()
  }.map { (_: Substring, path: Substring, _: Substring) in
    String(path)
  }

  static func bundle(
    _ context: BundlerContext,
    _ additionalContext: Context
  ) -> Result<Void, AppImageBundlerError> {
    let appBundleName = appBundleName(forAppName: context.appName)
    let appBundle = context.outputDirectory.appendingPathComponent(appBundleName)

    log.info("Bundling '\(appBundleName)'")

    let executableArtifact = context.productsDirectory
      .appendingPathComponent(context.appConfiguration.product)

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
        Self.copyResources(
          from: context.productsDirectory,
          to: appDir.appendingPathComponent("usr/bin")
        )
      },
      {
        Self.createDesktopFile(
          at: appDir,
          appName: context.appName,
          appConfiguration: context.appConfiguration
        )
      },
      copyAppIconIfPresent,
      {
        Self.copyDynamicLibraryDependencies(
          of: appExecutable,
          to: appDir.appendingPathComponent("usr/bin")
        )
      },
      { Self.createSymlinks(at: appDir, appName: context.appName) },
      {
        log.info("Converting '\(context.appName).AppDir' to '\(appBundleName)'")
        return AppImageTool.bundle(appDir: appDir, to: appBundle)
          .mapError { .failedToBundleAppDir($0) }
      }
    )

    return bundleApp()
  }

  static func appBundleName(forAppName appName: String) -> String {
    "\(appName).AppImage"
  }

  // MARK: Private methods

  private static func copyDynamicLibraryDependencies(
    of appExecutable: URL,
    to destination: URL
  ) -> Result<Void, AppImageBundlerError> {
    return Process.create(
      "ldd",
      arguments: [appExecutable.path],
      runSilentlyWhenNotVerbose: false
    )
    .getOutput()
    .mapError { error in
      .failedToEnumerateDynamicDependencies(error)
    }
    .flatMap { output in
      let lines = output.split(separator: "\n")
      for line in lines {
        guard let libraryPath = try? lddLineParser.parse(line) else {
          continue
        }

        let libraryURL = URL(fileURLWithPath: libraryPath)
        let destination = destination.appendingPathComponent(
          libraryURL.lastPathComponent
        )
        do {
          try FileManager.default.copyItem(
            at: libraryURL,
            to: destination
          )
        } catch {
          return .failure(
            .failedToCopyDynamicLibrary(
              source: libraryURL,
              destination: destination,
              error
            )
          )
        }
      }
      return .success()
    }
  }

  private static func copyResources(
    from sourceDirectory: URL,
    to destinationDirectory: URL
  ) -> Result<Void, AppImageBundlerError> {
    let contents: [URL]
    do {
      contents = try FileManager.default.contentsOfDirectory(
        at: sourceDirectory,
        includingPropertiesForKeys: nil,
        options: []
      )
    } catch {
      return .failure(.failedToEnumerateResourceBundles(directory: sourceDirectory, error))
    }

    for bundle in contents where bundle.pathExtension == "resources" {
      guard FileManager.default.itemExists(at: bundle, withType: .directory) else {
        continue
      }

      log.info("Copying resource bundle '\(bundle.lastPathComponent)'")
      let destinationBundle = destinationDirectory.appendingPathComponent(
        "\(bundle.deletingPathExtension().lastPathComponent).bundle"
      )

      do {
        try FileManager.default.copyItem(at: bundle, to: destinationBundle)
      } catch {
        return .failure(
          .failedToCopyResourceBundle(
            source: bundle,
            destination: destinationBundle,
            error
          )
        )
      }
    }

    return .success()
  }

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
    at outputDirectory: URL,
    appName: String
  ) -> Result<Void, AppImageBundlerError> {
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
    // The icon's path relative to the root of the AppDir
    let iconRelativePath = "usr/share/icons/hicolor/1024x1024/apps/\(appName).png"
    let icon = appDir.appendingPathComponent(iconRelativePath)

    // Create `.DirIcon` and `[AppName].png` if an icon is present. Both are
    // just symlinks to the real icon file at `iconRelativePath`.
    var operation: () -> Result<Void, AppImageBundlerError> = { .success() }
    if FileManager.default.fileExists(atPath: icon.path) {
      operation = flatten(
        operation,
        {
          Self.createSymlink(
            at: appDir.appendingPathComponent("\(appName).png"),
            withRelativeDestination: iconRelativePath
          )
        },
        {
          Self.createSymlink(
            at: appDir.appendingPathComponent(".DirIcon"),
            withRelativeDestination: "\(appName).png"
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
          withRelativeDestination: "usr/bin/\(appName)"
        )
      }
    )

    return operation()
  }

  /// - Parameters:
  ///   - symlink: The symlink file to create.
  ///   - relativeDestination: The target of the symlink (relative to the
  ///     directory containing the symlink).
  private static func createSymlink(
    at symlink: URL,
    withRelativeDestination relativeDestination: String
  ) -> Result<Void, AppImageBundlerError> {
    do {
      try FileManager.default.createSymbolicLink(
        atPath: symlink.path,
        withDestinationPath: relativeDestination
      )
    } catch {
      return .failure(
        .failedToCreateSymlink(
          source: symlink,
          relativeDestination: relativeDestination,
          error
        )
      )
    }

    return .success()
  }
}
