import Foundation
import Parsing

/// The bundler for creating Linux RPM packages. The output of this bundler
/// isn't executable.
enum RPMBundler: Bundler {
  typealias Context = Void

  static let outputIsRunnable = false

  static func intendedOutput(
    in context: BundlerContext,
    _ additionalContext: Void
  ) -> BundlerOutputStructure {
    let bundle = context.outputDirectory
      .appendingPathComponent("\(context.appName).rpm")
    return BundlerOutputStructure(
      bundle: bundle,
      executable: nil,
      additionalOutputs: []
    )
  }

  static func bundle(
    _ context: BundlerContext,
    _ additionalContext: Context
  ) -> Result<BundlerOutputStructure, RPMBundlerError> {
    let outputStructure = intendedOutput(in: context, additionalContext)
    let bundleName = outputStructure.bundle.lastPathComponent

    let appVersion = context.appConfiguration.version
    let rpmBuildDirectory = RPMBuildDirectory(
      at: context.outputDirectory / "rpmbuild",
      appName: context.appName,
      appVersion: appVersion
    )

    // The 'source' directory for our RPM. Doesn't actual contain source code
    // cause it's all pre-compiled.
    let sourceDirectory = context.outputDirectory / "\(context.appName)-\(appVersion)"

    let installationRoot = URL(fileURLWithPath: "/opt/\(context.appName)")
    return GenericLinuxBundler.bundle(
      context,
      GenericLinuxBundler.Context(
        cosmeticBundleName: bundleName,
        installationRoot: installationRoot
      )
    )
    .mapError(RPMBundlerError.failedToRunGenericBundler)
    .andThenDoSideEffect { _ in
      // Create the an `rpmbuild` directory with the structure required by the
      // rpmbuild tool.
      rpmBuildDirectory.createDirectories()
    }
    .andThenDoSideEffect { structure in
      // Copy `.generic` bundle to give it the name we want it to have inside
      // the .tar.gz archive.
      FileManager.default.copyItem(
        at: structure.root,
        to: sourceDirectory,
        onError: RPMBundlerError.failedToCopyGenericBundle
      )
    }
    .andThenDoSideEffect { structure in
      // Generate an archive of the source directory. Again, it's not actually
      // the source code of the app, but it is according to RPM terminology.
      log.info("Archiving bundle")
      return ArchiveTool.createTarGz(
        of: sourceDirectory,
        at: rpmBuildDirectory.appSourceArchive
      ).mapError(RPMBundlerError.failedToArchiveSources)
    }
    .andThenDoSideEffect { structure in
      // Generate the RPM spec for our 'build' process (no actual building
      // happens in our rpmbuild step, only copying and system setup such as
      // installing desktop files).
      log.info("Creating RPM spec file")
      let specContents = generateSpec(
        appName: context.appName,
        appIdentifier: context.appConfiguration.identifier,
        appVersion: appVersion,
        bundleStructure: structure,
        sourceArchiveName: rpmBuildDirectory.appSourceArchive.lastPathComponent,
        installationRoot: installationRoot
      )
      return specContents.write(to: rpmBuildDirectory.appSpec)
        .mapError { error in
          .failedToWriteSpecFile(rpmBuildDirectory.appSpec, error)
        }
    }
    .andThenDoSideEffect { _ in
      // Build the actual RPM.
      log.info("Running rpmbuild")
      let command = "rpmbuild"
      let arguments = [
        "--define", "_topdir \(rpmBuildDirectory.root.path)",
        "-v", "-bb", rpmBuildDirectory.appSpec.path,
      ]
      return Process.create(command, arguments: arguments)
        .runAndWait()
        .mapError { error in
          .failedToRunRPMBuildTool(command, error)
        }
    }
    .andThen { _ in
      // Find the produced RPM because rpmbuild doesn't really tell us where
      // it'll end up.
      FileManager.default.enumerator(
        at: rpmBuildDirectory.rpms,
        includingPropertiesForKeys: nil
      )
      .okOr(RPMBundlerError.failedToEnumerateRPMs(rpmBuildDirectory.rpms))
      .andThen { files in
        files.compactMap { file in
          file as? URL
        }.filter { file in
          file.pathExtension == "rpm"
        }.first.okOr(RPMBundlerError.failedToFindProducedRPM(rpmBuildDirectory.rpms))
      }
    }
    .andThen { rpmFile in
      // Copy the rpm file to the previously declared output location
      FileManager.default.copyItem(
        at: rpmFile,
        to: outputStructure.bundle,
        onError: RPMBundlerError.failedToCopyRPMToOutputDirectory
      )
    }
    .replacingSuccessValue(with: outputStructure)
  }

  /// Generates an RPM spec for the given application.
  static func generateSpec(
    appName: String,
    appIdentifier: String,
    appVersion: String,
    bundleStructure: GenericLinuxBundler.BundleStructure,
    sourceArchiveName: String,
    installationRoot: URL
  ) -> String {
    let relativeDesktopFileLocation = bundleStructure.desktopFile.path(
      relativeTo: bundleStructure.root
    )

    let relativeDBusServiceFileLocation = bundleStructure.dbusServiceFile.path(
      relativeTo: bundleStructure.root
    )

    // We install this as a 512x512 icon (even though it's 1024x1024)
    // because Linux doesn't seem to check for 1024x1024 icons, and it also
    // doesn't seem to care if the icon's size is incorrect. Will fix
    // eventually when revamping icon support.
    let relativeIconFileLocation = bundleStructure.icon1024x1024.path(
      relativeTo: bundleStructure.root
    )
    let iconFileDestination =
      "/usr/share/icons/hicolor/512x512/apps/\(bundleStructure.icon1024x1024.lastPathComponent)"

    let hasDBusService = FileManager.default.itemExists(
      at: bundleStructure.dbusServiceFile,
      withType: .file
    )
    let installDBusServiceCommand: String
    if hasDBusService {
      installDBusServiceCommand = """
        mkdir -p $RPM_BUILD_ROOT\(URL(fileURLWithPath: "/" + relativeDBusServiceFileLocation).deletingLastPathComponent().path)
        cp $RPM_BUILD_ROOT\(installationRoot.path)/\(relativeDBusServiceFileLocation) $RPM_BUILD_ROOT/\(relativeDBusServiceFileLocation)
        """
    } else {
      installDBusServiceCommand = "# No desktop service file present"
    }

    let hasIcon = FileManager.default.itemExists(
      at: bundleStructure.icon1024x1024,
      withType: .file
    )
    let installIconCommand: String
    if hasIcon {
      installIconCommand = """
        mkdir -p $RPM_BUILD_ROOT\(URL(fileURLWithPath: iconFileDestination).deletingLastPathComponent().path)
        cp $RPM_BUILD_ROOT\(installationRoot.path)/\(relativeIconFileLocation) $RPM_BUILD_ROOT\(iconFileDestination)
        """
    } else {
      installIconCommand = "# No icon file present"
    }

    return """
      Name:           \(appName)
      Version:        \(appVersion)
      Release:        1%{?dist}
      Summary:        An app bundled by Swift Bundler

      License:        MIT
      Source0:        \(sourceArchiveName)

      %global _enable_debug_package 0
      %global debug_package %{nil}
      %global __os_install_post /usr/lib/rpm/brp-compress %{nil}

      %description
      An app bundled by Swift Bundler

      %prep
      %setup

      %build

      %install
      rm -rf $RPM_BUILD_ROOT
      mkdir -p $RPM_BUILD_ROOT\(installationRoot.path)
      cp -R * $RPM_BUILD_ROOT\(installationRoot.path)
      mkdir -p $RPM_BUILD_ROOT\(URL(fileURLWithPath: "/" + relativeDesktopFileLocation).deletingLastPathComponent().path)
      cp $RPM_BUILD_ROOT\(installationRoot.path)/\(relativeDesktopFileLocation) $RPM_BUILD_ROOT/\(relativeDesktopFileLocation)
      \(installDBusServiceCommand)
      \(installIconCommand)

      %post
      xdg-desktop-menu forceupdate
      xdg-icon-resource forceupdate

      %clean
      rm -rf $RPM_BUILD_ROOT

      %files
      \(installationRoot.path)
      /\(relativeDesktopFileLocation)
      \(hasDBusService ? "/\(relativeDBusServiceFileLocation)" : "")
      \(hasIcon ? iconFileDestination : "")
      """
  }

  /// The structure of an `rpmbuild` directory.
  struct RPMBuildDirectory {
    /// The root directory of the structure.
    var root: URL
    var build: URL
    var buildRoot: URL
    var rpms: URL
    var sources: URL
    /// The app's `.tar.gz` source archive.
    var appSourceArchive: URL
    var specs: URL
    /// The app's RPM `.spec` file.
    var appSpec: URL
    var srpms: URL

    /// All directories described by this structure.
    var directories: [URL] {
      [root, build, buildRoot, rpms, sources, specs, srpms]
    }

    /// Describes the structure of an `rpmbuild` directory. Doesn't create
    /// anything on disk (see ``RPMBuildDirectory/createDirectories()``).
    init(at root: URL, appName: String, appVersion: String) {
      self.root = root
      build = root / "BUILD"
      buildRoot = root / "BUILDROOT"
      rpms = root / "RPMS"
      sources = root / "SOURCES"
      appSourceArchive = sources / "\(appName)-\(appVersion).tar.gz"
      specs = root / "SPECS"
      appSpec = specs / "\(appName).spec"
      srpms = root / "SRPMS"
    }

    /// Creates all directories described by this directory structure.
    func createDirectories() -> Result<Void, RPMBundlerError> {
      directories.tryForEach { directory in
        FileManager.default.createDirectory(
          at: directory,
          onError: RPMBundlerError.failedToCreateRPMBuildDirectory
        )
      }
    }
  }
}
