import Foundation
import Overture

/// A utility for copying dynamic libraries into an app bundle and updating the app executable's rpaths accordingly.
enum DynamicLibraryBundler {
  /// Copies the dynamic libraries within a build's products directory to an output directory.
  ///
  /// The app's executable's rpath is updated to reflect the new relative location of each dynamic library.
  /// - Parameters:
  ///   - appExecutable: The app executable to update the rpaths of.
  ///   - libraryDirectory: The directory to copy plain dynamic libraries to.
  ///   - frameworkDirectory: The directory to copy frameworks to.
  ///   - productsDirectory: The build's products directory (used to locate dynamic libraries that
  ///     aren't installed system wide).
  ///   - isXcodeBuild: If `true` the `PackageFrameworks` subdirectory will be searched for frameworks containing dynamic libraries instead.
  ///   - universal: Whether the build is a universal build or not. Only true if the build is a SwiftPM build and universal.
  ///   - makeStandAlone: If `true`, all non-system dynamic libraries depended on by the executable will
  ///     be moved into the app bundle, and relevant rpaths will be updated accordingly.
  /// - Returns: If an error occurs, a failure is returned.
  static func copyDynamicDependencies(
    dependedOnBy appExecutable: URL,
    toLibraryDirectory libraryDirectory: URL,
    orFrameworkDirectory frameworkDirectory: URL,
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

    return await copyDynamicDependencies(
      dependedOnBy: appExecutable,
      toLibraryDirectory: libraryDirectory,
      orFrameworkDirectory: frameworkDirectory,
      productsDirectory: productsDirectory,
      includeSystemWideDependencies: makeStandAlone
    )
  }

  /// Copies all dynamic libraries depended on by `binary`, an executable or
  /// dynamic library, to the specified directory. Updates the install names
  /// all dependencies and recursively copies the dependencies of each
  /// dependency as well.
  /// - Parameters:
  ///   - binary: The executable or dynamic library to copy the dependencies of.
  ///   - libraryDirectory: The directory to copy plain dynamic libraries to.
  ///   - frameworkDirectory: The directory to copy frameworks to.
  ///   - productsDirectory: The products directory produced by SwiftPM or Xcode.
  ///     Used to construct search paths.
  ///   - includeSystemWideDependencies: Enables an experimental mode in which
  ///     system-wide dependencies are also copied. This can be used to distribute
  ///     apps which rely on system dependencies such as Gtk, or on newer Swift
  ///     runtime features, but it's still quite flakey.
  static func copyDynamicDependencies(
    dependedOnBy binary: URL,
    toLibraryDirectory libraryDirectory: URL,
    orFrameworkDirectory frameworkDirectory: URL,
    productsDirectory: URL,
    includeSystemWideDependencies: Bool
  ) async -> Result<Void, DynamicLibraryBundlerError> {
    let dynamicDependencies: [String]
    switch await enumerateDynamicDependencies(of: binary) {
      case .success(let output):
        dynamicDependencies = output
      case .failure(let error):
        return .failure(error)
    }

    let uninterestingPrefixes = ["/usr/lib/", "/System/Library/"]
    let filteredDependencies = dynamicDependencies
      .filter { path in
        !uninterestingPrefixes.contains { prefix in
          path.starts(with: prefix)
        }
      }
      .filter { installName in
        return (
          installName.starts(with: rpathPrefix)
          // Due to concurrency back deployment, the concurrency runtime install name
          // is relative to the rpath, so we need a special case to exclude it.
          && installName != "@rpath/libswift_Concurrency.dylib"
        ) || includeSystemWideDependencies
      }

    for installName in filteredDependencies {
      let result = await copyDynamicDependency(
        dependedOnBy: binary,
        toLibraryDirectory: libraryDirectory,
        orFrameworkDirectory: frameworkDirectory,
        installName: installName,
        productsDirectory: productsDirectory,
        includeSystemWideDependencies: includeSystemWideDependencies
      )
      if case .failure(let error) = result {
        return .failure(error)
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

  private static func enumerateDynamicDependencies(
    of binary: URL
  ) async -> Result<[String], DynamicLibraryBundlerError> {
    let otoolOutput: String
    let process = Process.create("/usr/bin/otool", arguments: ["-L", binary.path])
    switch await process.getOutput() {
      case .success(let output):
        otoolOutput = output
      case .failure(let error):
        return .failure(.failedToEnumerateSystemWideDynamicDependencies(error))
    }

    let dependencies = otoolOutput.split(separator: "\n")
      .dropFirst()
      .map { (line: Substring) -> String in
        // We find the first opening parenthesis from starting from the end of
        // the string in case the install name contains an open parenthesis.
        let installName = line.dropFirst()
          .reversed()
          .split(separator: "(", maxSplits: 1)[1]
          .reversed()

        return String(installName)
          .trimmingCharacters(in: .whitespaces)
      }

    return .success(dependencies)
  }

  private static let rpathPrefix = "@rpath/"

  private static func locateDynamicDependency(installName: String, productsDirectory: URL) -> URL? {
    if installName.starts(with: rpathPrefix) {
      // TODO: Expand this logic to load search path from binary if possible (so that this
      //   doesn't break when an upstream tool changes something in the future).
      let searchPath = [
        productsDirectory,
        productsDirectory / "PackageFrameworks",
      ]
      let relativePath = String(installName.dropFirst(rpathPrefix.count))
      let locations = searchPath.map { $0 / relativePath }
      return locations.first(where: { $0.exists() })
    } else {
      return URL(fileURLWithPath: installName)
    }
  }

  private static func copyDynamicDependency(
    dependedOnBy binary: URL,
    toLibraryDirectory libraryDirectory: URL,
    orFrameworkDirectory frameworkDirectory: URL,
    installName: String,
    productsDirectory: URL,
    includeSystemWideDependencies: Bool
  ) async -> Result<Void, DynamicLibraryBundlerError> {
    guard let location = locateDynamicDependency(
      installName: installName,
      productsDirectory: productsDirectory
    ) else {
      log.warning("Failed to locate library with install name '\(installName)'")
      return .success()
    }
    let dylibLocation = location.resolvingSymlinksInPath()

    // Discover whether the dylib is from a framework or not
    var framework = dylibLocation
    var isFramework = false
    while framework.path != "/" {
      if framework.pathExtension == "framework" {
        isFramework = true
        break
      }
      framework = framework.deletingLastPathComponent()
    }

    let dependency = isFramework ? framework : dylibLocation

    // Compute output location
    let targetDirectory = isFramework ? frameworkDirectory : libraryDirectory
    var outputDependency = targetDirectory / dependency.lastPathComponent
    if !isFramework && outputDependency.pathExtension == "" {
      // Add `.dylib` path extension when copying (if not already present) so that the
      // code signer can easily locate all dylibs to sign.
      outputDependency = outputDependency.appendingPathExtension("dylib")
    }

    // Update the install name of the dylib
    let outputDylib = isFramework
      ? dependency.appendingPathComponent(dylibLocation.path(relativeTo: framework))
      : dependency
    let newRelativePath = outputDylib.path(
      relativeTo: binary.deletingLastPathComponent()
    )
    let newInstallName = "@rpath/\(newRelativePath)"
    if case let .failure(error) = await updateLibraryInstallName(
      in: binary,
      original: installName,
      new: newInstallName
    ) {
      return .failure(error)
    }

    // Avoid copying libraries twice
    guard !outputDependency.exists() else {
      return .success()
    }

    // Copy the library
    do {
      try FileManager.default.copyItem(
        at: dependency,
        to: outputDependency
      )
    } catch {
      return .failure(
        .failedToCopyDynamicLibrary(
          source: dependency, destination: outputDependency, error
        )
      )
    }

    // Recursively copy the dependencies of this library's dependencies.
    return await copyDynamicDependencies(
      dependedOnBy: outputDylib,
      toLibraryDirectory: libraryDirectory,
      orFrameworkDirectory: frameworkDirectory,
      productsDirectory: productsDirectory,
      includeSystemWideDependencies: includeSystemWideDependencies
    )
  }
}
