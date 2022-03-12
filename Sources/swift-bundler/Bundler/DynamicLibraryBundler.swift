import Foundation

enum DynamicLibraryBundlerError: LocalizedError {
  case failedToEnumerateDynamicLibraries(Error)
  case failedToCopyDynamicLibrary(Error)
  case failedToUpdateExecutableRPath(library: String, Error)
  case failedToGetOutputRelativePath
  case failedToGetOriginalRelativePath
}

/// A utility for copying dynamic libraries and updating an executable's rpaths accordingly.
enum DynamicLibraryBundler {
  /// Copies the dynamic libraries within a build's products directory to an output directory.
  ///
  /// The app's executable's rpath is updated to reflect the new relative location of each dynamic library.
  /// - Parameters:
  ///   - productsDirectory: A build's products directory.
  ///   - outputDirectory: The directory to copy the dynamic libraries to.
  ///   - appExecutable: The app executable to update the rpaths of.
  ///   - isXcodeBuild: If `true` the `PackageFrameworks` subdirectory will be searched for frameworks containing dynamic libraries instead.
  /// - Returns: If an error occurs, a failure is returned.
  static func copyDynamicLibraries(
    from productsDirectory: URL,
    to outputDirectory: URL,
    appExecutable: URL,
    isXcodeBuild: Bool
  ) -> Result<Void, DynamicLibraryBundlerError> {
    log.info("Copying dynamic libraries")
    
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
    guard let outputDirectoryRelativePath = outputDirectory.relativePath(from: appExecutable.deletingLastPathComponent()) else {
      return .failure(.failedToGetOutputRelativePath)
    }
    
    for (name, library) in libraries {
      log.info("Copying dynamic library '\(name)'")
      
      // Copy and rename the library
      do {
        try FileManager.default.copyItem(
          at: library,
          to: outputDirectory.appendingPathComponent("lib\(name).dylib"))
      } catch {
        return .failure(.failedToCopyDynamicLibrary(error))
      }
      
      // Update the executable's rpath to reflect the change of the library's location relative to the executable
      guard let originalRelativePath = library.relativePath(from: searchDirectory) else {
        return .failure(.failedToGetOriginalRelativePath)
      }
      
      let process = Process.create(
        "/usr/bin/install_name_tool",
        arguments: [
          "-change", "@rpath/\(originalRelativePath)", "@rpath/\(outputDirectoryRelativePath)/lib\(name).dylib",
          appExecutable.path
        ])
      
      if case let .failure(error) = process.runAndWait() {
        return .failure(.failedToUpdateExecutableRPath(library: name, error))
      }
    }
    
    return .success()
  }
  
  /// Enumerates the dynamic libraries within a build's products directory.
  ///
  /// If `isXcodeBuild` is true, frameworks will be searched instead for
  /// frameworks. The dynamic library inside each framework will then be returned.
  /// - Parameters:
  ///   - searchDirectory: The directory to search for dynamic libraries within.
  ///   - isXcodeBuild: If `true`, frameworks containing dynamic libraries will be searched for instead of dynamic libraries. The dynamic library wihtin each framework is returned.
  /// - Returns: Each dynamic library and its name.
  static func enumerateDynamicLibraries(_ searchDirectory: URL, isXcodeBuild: Bool) -> Result<[(name: String, file: URL)], DynamicLibraryBundlerError> {
    let libraries: [(name: String, file: URL)]
    
    // Enumerate directory contents
    let contents: [URL]
    do {
      contents = try FileManager.default.contentsOfDirectory(
        at: searchDirectory,
        includingPropertiesForKeys: nil,
        options: [])
    } catch {
      return .failure(.failedToEnumerateDynamicLibraries(error))
    }
    
    // Locate dylibs and parse library names from paths
    if isXcodeBuild {
      libraries = contents
        .filter { $0.pathExtension == "framework" }
        .map { framework in
          let name = framework.deletingPathExtension().lastPathComponent
          return (name: name, file: framework.appendingPathComponent("Versions/A/\(name)"))
        }
    } else {
      libraries = contents
        .filter { $0.pathExtension == "dylib" }
        .map { library in
          let name = library.deletingPathExtension().lastPathComponent.dropFirst(3)
          return (name: String(name), file: library)
        }
    }
    
    return .success(libraries)
  }
}
