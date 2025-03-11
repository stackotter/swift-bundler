import Foundation
import Overture

/// A utility for copying dynamic libraries into an app bundle and updating the app executable's rpaths accordingly.
enum DynamicLibraryBundler {
  /// Copies the dynamic libraries within a build's products directory to an output directory.
  ///
  /// The app's executable's rpath is updated to reflect the new relative location of each dynamic library.
  /// - Parameters:
  ///   - appExecutable: The app executable to update the rpaths of.
  ///   - outputDirectory: The directory to copy the dynamic libraries to.
  ///   - productsDirectory: The build's products directory (used to locate dynamic libraries that
  ///     aren't installed system wide).
  ///   - isXcodeBuild: If `true` the `PackageFrameworks` subdirectory will be searched for frameworks containing dynamic libraries instead.
  ///   - universal: Whether the build is a universal build or not. Only true if the build is a SwiftPM build and universal.
  ///   - makeStandAlone: If `true`, all non-system dynamic libraries depended on by the executable will
  ///     be moved into the app bundle, and relevant rpaths will be updated accordingly.
  /// - Returns: If an error occurs, a failure is returned.
  static func copyDynamicLibraries(
    dependedOnBy appExecutable: URL,
    to outputDirectory: URL,
    productsDirectory: URL,
    isXcodeBuild: Bool,
    universal: Bool,
    makeStandAlone: Bool
  ) async -> Result<Void, DynamicLibraryBundlerError> {
    log.info("Copying dynamic libraries")

    // Update the app's rpath
    if universal || isXcodeBuild {
      let original = "@executable_path/../lib"
      let new = "@executable_path"
      let process = Process.create(
        "/usr/bin/install_name_tool",
        arguments: ["-rpath", original, new, appExecutable.path]
      )
      if case let .failure(error) = await process.runAndWait() {
        return .failure(.failedToUpdateAppRPath(original: original, new: new, error))
      }
    }

    return await moveLibraryDependencies(
      of: appExecutable,
      to: outputDirectory,
      for: appExecutable,
      productsDirectory: productsDirectory,
      includeSystemWideDependencies: makeStandAlone
    )
  }

  static func moveLibraryDependencies(
    of binary: URL,
    to directory: URL,
    for executable: URL,
    productsDirectory: URL,
    includeSystemWideDependencies: Bool
  ) async -> Result<Void, DynamicLibraryBundlerError> {
    let otoolOutput: String
    let process = Process.create("/usr/bin/otool", arguments: ["-L", binary.path])
    switch await process.getOutput() {
      case .success(let output):
        otoolOutput = output
      case .failure(let error):
        return .failure(.failedToEnumerateSystemWideDynamicDependencies(error))
    }

    let uninterestingPrefixes = ["/usr/lib/", "/System/Library/"]
    let dependencies: [(installName: String, location: URL)] =
      otoolOutput.split(separator: "\n")
      .dropFirst()
      .map { line in
        // TODO: Handle entries with spaces
        String(line.dropFirst().split(separator: " ")[0])
      }
      .filter { path in
        !uninterestingPrefixes.contains { prefix in
          path.starts(with: prefix)
        }
      }
      .compactMap { path in
        let rpathPrefix = "@rpath/"
        let location: URL
        if path == "@rpath/libswift_Concurrency.dylib" {
          // Due to concurrency back deployment, the concurrency runtime install name
          // is relative to the rpath, so we need a special case for it.
          return nil
        } else if path.starts(with: rpathPrefix) {
          // TODO: Expand this logic to load search path from binary if possible (so that this
          //   doesn't break when an upstream tool changes something in the future).
          // Search basic rpath for library
          let searchPath = [
            productsDirectory,
            productsDirectory / "PackageFrameworks",
          ]
          let options = searchPath.map {
            $0 / String(path.dropFirst(rpathPrefix.count))
          }
          guard let libraryLocation = options.first(where: { $0.exists() }) else {
            log.warning("Failed to locate library with install name '\(path)'")
            return nil
          }
          location = libraryLocation
        } else if includeSystemWideDependencies {
          location = URL(fileURLWithPath: path)
        } else {
          return nil
        }
        return (installName: path, location: location)
      }

    for (originalInstallName, location) in dependencies {
      let resolvedDependency = location.resolvingSymlinksInPath()

      // Copy and rename the library
      var outputLibrary = directory / resolvedDependency.lastPathComponent
      // Add `.dylib` path extension when copying (if not already present) so that the
      // code signer can easily locate all dylibs to sign.
      if outputLibrary.pathExtension == "" {
        outputLibrary = outputLibrary.appendingPathExtension("dylib")
      }

      let libraryAlreadyCopied = FileManager.default.fileExists(atPath: outputLibrary.path)
      if !libraryAlreadyCopied {
        do {
          try FileManager.default.copyItem(
            at: resolvedDependency,
            to: outputLibrary
          )
        } catch {
          return .failure(
            .failedToCopyDynamicLibrary(
              source: resolvedDependency, destination: outputLibrary, error
            )
          )
        }
      }

      let newRelativePath = outputLibrary.path(
        relativeTo: executable.deletingLastPathComponent()
      )

      if case let .failure(error) = await updateLibraryInstallName(
        in: binary,
        original: originalInstallName,
        new: "@rpath/\(newRelativePath)"
      ) {
        return .failure(error)
      }

      if !libraryAlreadyCopied {
        let result = await moveLibraryDependencies(
          of: outputLibrary,
          to: directory,
          for: executable,
          productsDirectory: productsDirectory,
          includeSystemWideDependencies: includeSystemWideDependencies
        )
        if case let .failure(error) = result {
          return .failure(error)
        }
      }
    }

    return .success()
  }

  /// Updates the install name of a library that has changed locations relative
  /// to the executable.
  /// - Parameters:
  ///   - library: The library's name.
  ///   - executable: The executable to update the install name in.
  ///   - originalLibraryLocation: The library's original location.
  ///   - newLibraryLocation: The library's new location.
  ///   - librarySearchDirectory: The original place that the executable would've
  ///     searched for libraries.
  /// - Returns: If an error occurs, a failure is returned.
  static func updateLibraryInstallName(
    of library: String,
    in executable: URL,
    originalLibraryLocation: URL,
    newLibraryLocation: URL,
    librarySearchDirectory: URL
  ) async -> Result<Void, DynamicLibraryBundlerError> {
    let originalRelativePath = originalLibraryLocation.path(
      relativeTo: librarySearchDirectory
    )
    let newRelativePath = newLibraryLocation.path(
      relativeTo: executable.deletingLastPathComponent()
    )

    return await updateLibraryInstallName(
      in: executable,
      original: "@rpath/\(originalRelativePath)",
      new: "@rpath/\(newRelativePath)"
    )
  }

  /// Updates the install name of a library that has been moved.
  /// - Parameters:
  ///   - executable: The executable to update the install name in.
  ///   - originalInstallName: The library's original install name.
  ///   - newInstallName: The library's new install name.
  /// - Returns: If an error occurs, a failure is returned.
  static func updateLibraryInstallName(
    in executable: URL,
    original originalInstallName: String,
    new newInstallName: String
  ) async -> Result<Void, DynamicLibraryBundlerError> {
    let process = Process.create(
      "/usr/bin/install_name_tool",
      arguments: [
        "-change",
        originalInstallName,
        newInstallName,
        executable.path,
      ]
    )

    return await process.runAndWait().mapError { error in
      .failedToUpdateLibraryInstallName(
        library: nil,
        original: originalInstallName,
        new: newInstallName,
        error
      )
    }
  }

  /// Enumerates the dynamic libraries within a build's products directory.
  ///
  /// If `isXcodeBuild` is true, frameworks will be searched instead for
  /// frameworks. The dynamic library inside each framework will then be returned.
  /// - Parameters:
  ///   - searchDirectory: The directory to search for dynamic libraries within.
  ///   - isXcodeBuild: If `true`, frameworks containing dynamic libraries will be searched for instead of dynamic libraries.
  /// - Returns: Each dynamic library and its name, or a failure if an error occurs.
  static func enumerateDynamicLibraries(
    _ searchDirectory: URL,
    isXcodeBuild: Bool
  ) -> Result<[(name: String, file: URL)], DynamicLibraryBundlerError> {
    let libraries: [(name: String, file: URL)]

    // Enumerate directory contents
    let contents: [URL]
    do {
      contents = try FileManager.default.contentsOfDirectory(
        at: searchDirectory,
        includingPropertiesForKeys: nil,
        options: [])
    } catch {
      return .failure(.failedToEnumerateDynamicLibraries(directory: searchDirectory, error))
    }

    // Locate dylibs and parse library names from paths
    if isXcodeBuild {
      libraries =
        contents
        .filter { $0.pathExtension == "framework" }
        .map { framework in
          let name = framework.deletingPathExtension().lastPathComponent
          let versionsDirectory = framework / "Versions"
          if versionsDirectory.exists() {
            return (
              name: name,
              file: versionsDirectory / "A/\(name)"
            )
          } else {
            return (
              name: name,
              file: framework / name
            )
          }
        }
    } else {
      libraries =
        contents
        .filter { $0.pathExtension == "dylib" }
        .map { library in
          let name = library.deletingPathExtension().lastPathComponent
          return (name: name, file: library)
        }
    }

    return .success(libraries)
  }
}
