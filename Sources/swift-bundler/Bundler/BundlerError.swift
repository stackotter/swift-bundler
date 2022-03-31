import Foundation

/// An error returned by ``Bundler``.
enum BundlerError: LocalizedError {
  case failedToBuild(product: String, SwiftPackageManagerError)
  case failedToCreateAppBundleDirectoryStructure(bundleDirectory: URL, Error)
  case failedToCreatePkgInfo(file: URL, Error)
  case failedToCreateInfoPlist(PlistCreatorError)
  case failedToCopyExecutable(source: URL, destination: URL, Error)
  case failedToCreateIcon(IconSetCreatorError)
  case failedToCopyICNS(source: URL, destination: URL, Error)
  case failedToCopyResourceBundles(ResourceBundlerError)
  case failedToCopyDynamicLibraries(DynamicLibraryBundlerError)
  case failedToRunExecutable(ProcessError)
  case failedToGetApplicationSupportDirectory(Error)
  case failedToCreateApplicationSupportDirectory(Error)
  case invalidAppIconFile(URL)
  case invalidArchitecture(String)
  case invalidBuildConfiguration(String)

  var errorDescription: String? {
    switch self {
      case .failedToBuild(let product, let swiftPackageManagerError):
        return "Failed to build '\(product)': \(swiftPackageManagerError.localizedDescription)'"
      case .failedToCreateAppBundleDirectoryStructure(let bundleDirectory, _):
        return "Failed to create app bundle directory structure at '\(bundleDirectory)'"
      case .failedToCreatePkgInfo(let file, _):
        return "Failed to create 'PkgInfo' file at '\(file)'"
      case .failedToCreateInfoPlist(let plistCreatorError):
        return "Failed to create 'Info.plist': \(plistCreatorError.localizedDescription)"
      case .failedToCopyExecutable(let source, let destination, _):
        return "Failed to copy executable from '\(source.relativePath)' to '\(destination.relativePath)'"
      case .failedToCreateIcon(let iconSetCreatorError):
        return "Failed to create app icon: \(iconSetCreatorError.localizedDescription)"
      case .failedToCopyICNS(let source, let destination, _):
        return "Failed to copy 'icns' file from '\(source.relativePath)' to '\(destination.relativePath)'"
      case .failedToCopyResourceBundles(let resourceBundlerError):
        return "Failed to copy resource bundles: \(resourceBundlerError.localizedDescription)"
      case .failedToCopyDynamicLibraries(let dynamicLibraryBundlerError):
        return "Failed to copy dynamic libraries: \(dynamicLibraryBundlerError.localizedDescription)"
      case .failedToRunExecutable(let processError):
        return "Failed to run app executable: \(processError.localizedDescription)"
      case .failedToGetApplicationSupportDirectory:
        return "Failed to get application support directory"
      case .failedToCreateApplicationSupportDirectory:
        return "Failed to create application support directory"
      case .invalidAppIconFile(let file):
        return "Invalid app icon file, must be 'png' or 'icns', got '\(file.relativePath)'"
      case .invalidArchitecture(let arch):
        let validArchitectures = SwiftPackageManager.Architecture.allCases.map(\.rawValue).joined(separator: ", ")
        return "'\(arch)' is not a valid architecture. Valid architectures: [\(validArchitectures)]"
      case .invalidBuildConfiguration(let configuration):
        let validConfigurations = SwiftPackageManager.BuildConfiguration.allCases.map(\.rawValue).joined(separator: ", ")
        return "'\(configuration)' is not a valid configuration. Valid configurations: [\(validConfigurations)]"
    }
  }
}
