import Foundation

/// An error returned by ``VisionOSBundler``.
enum VisionOSBundlerError: LocalizedError {
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
  case invalidAppIconFile(URL)
  case failedToCopyProvisioningProfile(Error)
  case failedToCodesign(CodeSignerError)
  case mustSpecifyBundleIdentifier
  case failedToLoadManifest(SwiftPackageManagerError)
  case failedToGetMinimumVisionOSVersion(manifest: URL)

  var errorDescription: String? {
    switch self {
      case let .failedToBuild(product, swiftPackageManagerError):
        return "Failed to build '\(product)': \(swiftPackageManagerError.localizedDescription)'"
      case let .failedToCreateAppBundleDirectoryStructure(bundleDirectory, _):
        return "Failed to create app bundle directory structure at '\(bundleDirectory)'"
      case let .failedToCreatePkgInfo(file, _):
        return "Failed to create 'PkgInfo' file at '\(file)'"
      case let .failedToCreateInfoPlist(plistCreatorError):
        return "Failed to create 'Info.plist': \(plistCreatorError.localizedDescription)"
      case let .failedToCopyExecutable(source, destination, _):
        return
          "Failed to copy executable from '\(source.relativePath)' to '\(destination.relativePath)'"
      case let .failedToCreateIcon(iconSetCreatorError):
        return "Failed to create app icon: \(iconSetCreatorError.localizedDescription)"
      case let .failedToCopyICNS(source, destination, _):
        return
          "Failed to copy 'icns' file from '\(source.relativePath)' to '\(destination.relativePath)'"
      case let .failedToCopyResourceBundles(resourceBundlerError):
        return "Failed to copy resource bundles: \(resourceBundlerError.localizedDescription)"
      case let .failedToCopyDynamicLibraries(dynamicLibraryBundlerError):
        return
          "Failed to copy dynamic libraries: \(dynamicLibraryBundlerError.localizedDescription)"
      case let .failedToRunExecutable(processError):
        return "Failed to run app executable: \(processError.localizedDescription)"
      case let .invalidAppIconFile(file):
        return "Invalid app icon file, must be 'png' or 'icns', got '\(file.relativePath)'"
      case .failedToCopyProvisioningProfile:
        return "Failed to copy provisioning profile to output bundle"
      case let .failedToCodesign(error):
        return error.localizedDescription
      case .mustSpecifyBundleIdentifier:
        return "Bundle identifier must be specified for visionOS apps"
      case let .failedToLoadManifest(error):
        return error.localizedDescription
      case let .failedToGetMinimumVisionOSVersion(manifest):
        return
          "To build for visionOS, please specify a visionOS deployment version in the platforms field of '\(manifest.relativePath)'"
    }
  }
}
