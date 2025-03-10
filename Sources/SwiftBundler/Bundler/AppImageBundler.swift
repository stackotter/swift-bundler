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
  ) async -> Result<BundlerOutputStructure, AppImageBundlerError> {
    let outputStructure = intendedOutput(in: context, additionalContext)
    let appDir = context.outputDirectory
      .appendingPathComponent("\(context.appName).AppDir")
    let bundleName = outputStructure.bundle.lastPathComponent

    return await GenericLinuxBundler.bundle(
      context,
      GenericLinuxBundler.Context(cosmeticBundleName: bundleName)
    )
    .mapError(AppImageBundlerError.failedToRunGenericBundler)
    .andThenDoSideEffect { structure in
      log.info("Creating symlinks")
      return createSymlinks(in: structure)
    }
    .andThenDoSideEffect { structure in
      // Copy the app's desktop file to the root of the output directory for
      // convenience.
      return FileManager.default.copyItem(
        at: structure.desktopFile,
        to: desktopFileLocation(for: context),
        onError: AppImageBundlerError.failedToCopyDesktopFile
      )
    }
    .andThenDoSideEffect { structure in
      // This isn't strictly necessary but it's probably a nice courtesy to
      // anyone poking around in the outputs of this bundler if we let them
      // know that the directory in question is meant to be an `AppDir`.
      FileManager.default.moveItem(
        at: structure.root,
        to: appDir,
        onError: AppImageBundlerError.failedToRenameGenericBundle
      )
    }
    .andThenDoSideEffect { structure in
      log.info("Converting '\(context.appName).AppDir' to '\(bundleName)'")
      return await AppImageTool.bundle(appDir: appDir, to: outputStructure.bundle)
        .mapError { .failedToBundleAppDir($0) }
    }
    .replacingSuccessValue(with: outputStructure)
  }

  // MARK: Private methods

  /// Creates the symlinks required to turn a generic bundle into an `AppDir`.
  private static func createSymlinks(
    in structure: GenericLinuxBundler.BundleStructure
  ) -> Result<Void, AppImageBundlerError> {
    return Result.success()
      .andThen { _ in
        // Create `.DirIcon` and `[AppName].png` if an icon is present. Both are
        // just symlinks to the real icon file at `iconRelativePath`.
        let icon = structure.icon1024x1024
        guard FileManager.default.fileExists(atPath: icon.path) else {
          return .success()
        }

        let relativeIconPath = icon.path(relativeTo: structure.root)
        return FileManager.default.createSymlink(
          at: structure.root.appendingPathComponent(icon.lastPathComponent),
          withRelativeDestination: relativeIconPath,
          onError: AppImageBundlerError.failedToCreateSymlink
        )
        .andThen { _ in
          FileManager.default.createSymlink(
            at: structure.root.appendingPathComponent(".DirIcon"),
            withRelativeDestination: icon.lastPathComponent,
            onError: AppImageBundlerError.failedToCreateSymlink
          )
        }
      }
      .andThen { (_: Void) in
        // Create `AppRun` symlink pointing to the main executable.
        FileManager.default.createSymlink(
          at: structure.root.appendingPathComponent("AppRun"),
          withRelativeDestination: structure.mainExecutable
            .path(relativeTo: structure.root),
          onError: AppImageBundlerError.failedToCreateSymlink
        )
      }
      .andThen { (_: Void) in
        // Create symlink in root pointing to desktop file.
        FileManager.default.createSymlink(
          at: structure.root.appendingPathComponent(
            structure.desktopFile.lastPathComponent
          ),
          withRelativeDestination: structure.desktopFile
            .path(relativeTo: structure.root),
          onError: AppImageBundlerError.failedToCreateSymlink
        )
      }
  }
}
