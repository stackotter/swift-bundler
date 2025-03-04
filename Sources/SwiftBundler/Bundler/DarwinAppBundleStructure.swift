import Foundation

/// The file/directory structure of a particular app bundle on disk.
struct DarwinAppBundleStructure {
  let contentsDirectory: URL
  let resourcesDirectory: URL
  let librariesDirectory: URL
  let executableDirectory: URL
  let infoPlistFile: URL
  let pkgInfoFile: URL
  let provisioningProfileFile: URL
  let appIconFile: URL
  let mainExecutable: URL

  /// Describes the structure of an app bundle for the specific platform. Doesn't
  /// create anything on disk (see ``DarwinAppBundleStructure/createDirectories()``).
  init(at bundleDirectory: URL, platform: ApplePlatform, appName: String) {
    let os = platform.os
    switch os {
      case .macOS:
        contentsDirectory = bundleDirectory.appendingPathComponent("Contents")
        executableDirectory = contentsDirectory.appendingPathComponent("MacOS")
        resourcesDirectory = contentsDirectory.appendingPathComponent("Resources")
      case .iOS, .tvOS, .visionOS:
        contentsDirectory = bundleDirectory
        executableDirectory = contentsDirectory
        resourcesDirectory = contentsDirectory
    }

    librariesDirectory = contentsDirectory.appendingPathComponent("Libraries")

    infoPlistFile = contentsDirectory.appendingPathComponent("Info.plist")
    pkgInfoFile = contentsDirectory.appendingPathComponent("PkgInfo")
    provisioningProfileFile = contentsDirectory.appendingPathComponent(
      "embedded.mobileprovision"
    )
    appIconFile = resourcesDirectory.appendingPathComponent("AppIcon.icns")

    mainExecutable = executableDirectory.appendingPathComponent(appName)
  }

  /// Attempts to create all directories within the app bundle. Ignores directories which
  /// already exist.
  func createDirectories() -> Result<Void, DarwinBundlerError> {
    let directories = [
      contentsDirectory, resourcesDirectory, librariesDirectory, executableDirectory,
    ]

    return directories.filter { directory in
      !FileManager.default.itemExists(at: directory, withType: .directory)
    }.tryForEach { directory in
      FileManager.default.createDirectory(at: directory)
        .mapError(DarwinBundlerError.failedToCreateAppBundleDirectoryStructure)
    }
  }
}
