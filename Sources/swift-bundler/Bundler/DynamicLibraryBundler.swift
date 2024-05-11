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
  ) -> Result<Void, DynamicLibraryBundlerError> {
    log.info("Copying dynamic libraries")

    // Update the app's rpath
    if universal || isXcodeBuild {
      let original = "@executable_path/../lib"
      let new = "@executable_path"
      let process = Process.create(
        "/usr/bin/install_name_tool",
        arguments: ["-rpath", original, new, appExecutable.path]
      )
      if case let .failure(error) = process.runAndWait() {
        return .failure(.failedToUpdateAppRPath(original: original, new: new, error))
      }
    }

    // Select directory to enumerate
    let searchDirectory: URL
    if isXcodeBuild {
      searchDirectory = productsDirectory.appendingPathComponent("PackageFrameworks")
    } else {
      searchDirectory = productsDirectory
    }

    // Enumerate dynamic libraries
    let libraries: [(name: String, file: URL)]
    switch enumerateDynamicLibraries(searchDirectory, isXcodeBuild: isXcodeBuild) {
      case let .success(value):
        libraries = value
      case let .failure(error):
        return .failure(error)
    }

    // Copy dynamic libraries
    for (name, library) in libraries {
      log.info("Copying dynamic library '\(name)'")

      // Copy and rename the library
      let outputLibrary = outputDirectory.appendingPathComponent("lib\(name).dylib")
      do {
        try FileManager.default.copyItem(
          at: library,
          to: outputLibrary
        )
      } catch {
        return .failure(
          .failedToCopyDynamicLibrary(source: library, destination: outputLibrary, error)
        )
      }

      // Update the install name of the library to reflect the change of location relative to the executable
      let result = updateLibraryInstallName(
        of: name,
        in: appExecutable,
        originalLibraryLocation: library,
        newLibraryLocation: outputLibrary,
        librarySearchDirectory: searchDirectory
      )
      if case .failure = result {
        return result
      }
    }

    if makeStandAlone {
      return moveSystemWideLibraryDependencies(
        of: appExecutable,
        to: outputDirectory,
        for: appExecutable
      )
    } else {
      return .success()
    }
  }

  static func moveSystemWideLibraryDependencies(
    of binary: URL,
    to directory: URL,
    for executable: URL
  ) -> Result<Void, DynamicLibraryBundlerError> {
    let otoolOutput: String
    let process = Process.create("/usr/bin/otool", arguments: ["-L", binary.path])
    switch process.getOutput() {
      case .success(let output):
        otoolOutput = output
      case .failure(let error):
        return .failure(.failedToEnumerateSystemWideDynamicDependencies(error))
    }

    let parse = pipe(
      flip(Substring.dropFirst)(1),
      { $0.split(separator: " ")[0] },
      String.init,
      URL.init(fileURLWithPath:)
    )

    let isntPrefixOf: (String) -> (String) -> Bool = { pipe($0.starts(with:), !) }
    let uninterestingPrefixes = ["/usr/lib/", "/System/Library/", "@rpath"]
    let dependencies = otoolOutput.split(separator: "\n").dropFirst()
      .map(parse)
      .filter { dependency in
        uninterestingPrefixes.allSatisfy(isntPrefixOf(dependency.path))
      }

    for dependency in dependencies {
      let resolvedDependency = dependency.resolvingSymlinksInPath()

      // Copy and rename the library
      let outputLibrary = directory.appendingPathComponent(resolvedDependency.lastPathComponent)
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

      guard
        let newRelativePath = outputLibrary.relativePath(
          from: executable.deletingLastPathComponent())
      else {
        return .failure(
          .failedToGetNewPathRelativeToExecutable(
            library: resolvedDependency.lastPathComponent,
            newPath: outputLibrary,
            executable: binary
          )
        )
      }

      if case let .failure(error) = updateLibraryInstallName(
        in: binary,
        original: dependency.path,
        new: "@rpath/\(newRelativePath)"
      ) {
        return .failure(error)
      }

      if !libraryAlreadyCopied {
        let result = moveSystemWideLibraryDependencies(
          of: outputLibrary,
          to: directory,
          for: executable
        )
        if case let .failure(error) = result {
          return .failure(error)
        }
      }

      if case let .failure(error) = CodeSigner.signAdHoc(file: outputLibrary) {
        return .failure(.failedToSignMovedLibrary(error))
      }
    }

    return .success()
  }

  /// Updates the install name of a library that has changed locations relative to the executable.
  /// - Parameters:
  ///   - library: The library's name.
  ///   - executable: The executable to update the install name in.
  ///   - originalLibraryLocation: The library's original location.
  ///   - newLibraryLocation: The library's new location.
  ///   - librarySearchDirectory: The original place that the executable would've searched for libraries.
  /// - Returns: If an error occurs, a failure is returned.
  static func updateLibraryInstallName(
    of library: String,
    in executable: URL,
    originalLibraryLocation: URL,
    newLibraryLocation: URL,
    librarySearchDirectory: URL
  ) -> Result<Void, DynamicLibraryBundlerError> {
    guard
      let originalRelativePath = originalLibraryLocation.relativePath(from: librarySearchDirectory)
    else {
      return .failure(
        .failedToGetOriginalPathRelativeToSearchDirectory(
          library: library,
          originalPath: originalLibraryLocation,
          searchDirectory: librarySearchDirectory
        )
      )
    }

    guard
      let newRelativePath = newLibraryLocation.relativePath(
        from: executable.deletingLastPathComponent())
    else {
      return .failure(
        .failedToGetNewPathRelativeToExecutable(
          library: library,
          newPath: newLibraryLocation,
          executable: executable
        )
      )
    }

    return updateLibraryInstallName(
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
  ) -> Result<Void, DynamicLibraryBundlerError> {
    let process = Process.create(
      "/usr/bin/install_name_tool",
      arguments: [
        "-change",
        originalInstallName,
        newInstallName,
        executable.path,
      ]
    )

    return process.runAndWait().mapError { error in
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
          return (name: name, file: framework.appendingPathComponent("Versions/A/\(name)"))
        }
    } else {
      libraries =
        contents
        .filter { $0.pathExtension == "dylib" }
        .map { library in
          let name = library.deletingPathExtension().lastPathComponent.dropFirst(3)
          return (name: String(name), file: library)
        }
    }

    return .success(libraries)
  }
}
