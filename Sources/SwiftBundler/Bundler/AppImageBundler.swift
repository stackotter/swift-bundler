import Foundation
import Parsing

/// The bundler for creating Linux AppImages.
enum AppImageBundler: Bundler {
  typealias Context = Void

  static let outputIsRunnable = true

  /// Computes the location of the desktop file created in the given context.
  static func desktopFileLocation(for context: BundlerContext) -> URL {
    context.outputDirectory.appendingPathComponent(
      GenericLinuxBundler.BundleStructure
        .desktopFileName(for: context.appName)
    )
  }

  static func intendedOutput(
    in context: BundlerContext,
    _ additionalContext: Void
  ) -> BundlerOutputStructure {
    let bundle = context.outputDirectory
      .appendingPathComponent("\(context.appName).AppImage")
    return BundlerOutputStructure(
      bundle: bundle,
      executable: bundle,
      additionalOutputs: [
        desktopFileLocation(for: context)
      ]
    )
  }

  static func bundle(
    _ context: BundlerContext,
    _ additionalContext: Context
  ) async throws(Error) -> BundlerOutputStructure {
    let outputStructure = intendedOutput(in: context, additionalContext)
    let bundleName = outputStructure.bundle.lastPathComponent

    // Run generic bundler
    let structure: GenericLinuxBundler.BundleStructure = try await Error.catch {
      try await GenericLinuxBundler.bundle(
        context,
        GenericLinuxBundler.Context(cosmeticBundleName: bundleName)
      )
    }

    try createSymlinks(in: structure)

    // Copy the app's desktop file to the root of the output directory for
    // convenience.
    let desktopFileDestination = desktopFileLocation(for: context)
    do {
      try FileManager.default.copyItem(at: structure.desktopFile, to: desktopFileDestination)
    } catch {
      let message = ErrorMessage.failedToCopyDesktopFile(
        source: structure.desktopFile,
        destination: desktopFileDestination
      )
      throw Error(message, cause: error)
    }

    // This isn't strictly necessary but it's probably a nice courtesy to
    // anyone poking around in the outputs of this bundler if we let them
    // know that the directory in question is meant to be an `AppDir`.
    let appDir = context.outputDirectory / "\(context.appName).AppDir"
    do {
      try FileManager.default.moveItem(at: structure.root, to: appDir)
    } catch {
      throw Error(
        .failedToRenameGenericBundle(source: structure.root, destination: appDir),
        cause: error
      )
    }

    log.info("Converting '\(context.appName).AppDir' to '\(bundleName)'")
    do {
      try await AppImageTool.bundle(appDir: appDir, to: outputStructure.bundle)
    } catch {
      throw Error(.failedToBundleAppDir, cause: error)
    }

    return outputStructure
  }

  // MARK: Private methods

  /// Creates the symlinks required to turn a generic bundle into an `AppDir`.
  private static func createSymlinks(
    in structure: GenericLinuxBundler.BundleStructure
  ) throws(Error) {
    // Create `.DirIcon` and `[AppName].png` if an icon is present. Both are
    // just symlinks to the real icon file at `iconRelativePath`.
    let icon = structure.icon1024x1024
    guard FileManager.default.fileExists(atPath: icon.path) else {
      return
    }

    let relativeIconPath = icon.path(relativeTo: structure.root)
    try createSymlink(
      at: structure.root / icon.lastPathComponent,
      withRelativeDestination: relativeIconPath
    )

    try createSymlink(
      at: structure.root / ".DirIcon",
      withRelativeDestination: icon.lastPathComponent
    )

    // Create `AppRun` symlink pointing to the main executable.
    try createSymlink(
      at: structure.root / "AppRun",
      withRelativeDestination: structure.mainExecutable.path(relativeTo: structure.root)
    )

    // Create symlink in root pointing to desktop file.
    try createSymlink(
      at: structure.root / structure.desktopFile.lastPathComponent,
      withRelativeDestination: structure.desktopFile.path(relativeTo: structure.root)
    )
  }

  private static func createSymlink(
    at source: URL,
    withRelativeDestination relativeDestination: String
  ) throws(Error) {
    do {
      try FileManager.default.createSymlink(
        at: source,
        withRelativeDestination: relativeDestination
      ).unwrap()
    } catch {
      throw Error(
        .failedToCreateSymlink(source: source, relativeDestination: relativeDestination),
        cause: error
      )
    }
  }
}
