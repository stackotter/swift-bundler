import Foundation

/// An error returned by ``DarwinBundler``.
enum DarwinBundlerError: LocalizedError {
  case failedToBuild(product: String, SwiftPackageManagerError)
  case failedToRemoveExistingAppBundle(bundle: URL, Error)
  case failedToCreateAppBundleDirectoryStructure(Error)
  case failedToCreatePkgInfo(file: URL, Error)
  case failedToCreateInfoPlist(PlistCreatorError)
  case failedToCopyExecutable(source: URL, destination: URL, Error)
  case failedToCopyExecutableDependency(
    name: String,
    source: URL,
    destination: URL,
    Error
  )
  case failedToCreateIcon(IconSetCreatorError)
  case failedToCopyICNS(source: URL, destination: URL, Error)
  case failedToCopyResourceBundles(ResourceBundlerError)
  case failedToCopyDynamicLibraries(DynamicLibraryBundlerError)
  case failedToRunExecutable(ProcessError)
  case invalidAppIconFile(URL)
  case failedToCodesign(CodeSignerError)
  case failedToLoadManifest(SwiftPackageManagerError)
  case failedToGetMinimumMacOSVersion(manifest: URL)
  case failedToCopyProvisioningProfile(Error)
  case missingDarwinPlatformVersion(Platform)
  case unsupportedPlatform(Platform)
  case failedToInsertMetadata(MetadataInserterError)
  case missingTargetDevice(Platform)
  case failedToGenerateProvisioningProfile(ProvisioningProfileManager.Error?)

  var errorDescription: String? {
    switch self {
      case .failedToBuild(let product, let swiftPackageManagerError):
        return "Failed to build '\(product)': \(swiftPackageManagerError.localizedDescription)'"
      case .failedToRemoveExistingAppBundle(let bundle, _):
        return "Failed to remove existing app bundle at '\(bundle.relativePath)'"
      case .failedToCreateAppBundleDirectoryStructure(let error):
        return "Failed to create app bundle directory structure: \(error)"
      case .failedToCreatePkgInfo(let file, _):
        return "Failed to create 'PkgInfo' file at '\(file)'"
      case .failedToCreateInfoPlist(let plistCreatorError):
        return "Failed to create 'Info.plist': \(plistCreatorError.localizedDescription)"
      case .failedToCopyExecutable(let source, let destination, _):
        return
          "Failed to copy executable from '\(source.relativePath)' to '\(destination.relativePath)'"
      case .failedToCopyExecutableDependency(let dependencyName, let source, let destination, _):
        return
          """
          Failed to copy executable dependency '\(dependencyName)' from \
          '\(source.relativePath)' to '\(destination.relativePath)'
          """
      case .failedToCreateIcon(let iconSetCreatorError):
        return "Failed to create app icon: \(iconSetCreatorError.localizedDescription)"
      case .failedToCopyICNS(let source, let destination, _):
        return
          "Failed to copy 'icns' file from '\(source.relativePath)' to '\(destination.relativePath)'"
      case .failedToCopyResourceBundles(let resourceBundlerError):
        return "Failed to copy resource bundles: \(resourceBundlerError.localizedDescription)"
      case .failedToCopyDynamicLibraries(let dynamicLibraryBundlerError):
        return
          "Failed to copy dynamic libraries: \(dynamicLibraryBundlerError.localizedDescription)"
      case .failedToRunExecutable(let processError):
        return "Failed to run app executable: \(processError.localizedDescription)"
      case .invalidAppIconFile(let file):
        return "Invalid app icon file, must be 'png' or 'icns', got '\(file.relativePath)'"
      case .failedToCodesign(let error):
        return error.localizedDescription
      case .failedToLoadManifest(let error):
        return error.localizedDescription
      case .failedToGetMinimumMacOSVersion(let manifest):
        return """
          To build for macOS, please specify a macOS deployment version in the \
          platforms field of '\(manifest.relativePath)'
          """
      case .failedToCopyProvisioningProfile:
        return "Failed to copy provisioning profile to output bundle"
      case .missingDarwinPlatformVersion(let platform):
        return """
          Missing target platform version for '\(platform.rawValue)' in \
          'Package.swift'. Please update the `Package.platforms` array \
          and try again. Bundling for Darwin platforms requires a target \
          platform.
          """
      case .unsupportedPlatform(let platform):
        return """
          Platform '\(platform.name)' not supported by \
          '\(BundlerChoice.darwinApp.rawValue)' bundler.
          """
      case .failedToInsertMetadata(let error):
        return error.localizedDescription
      case .missingTargetDevice(let platform):
        return """
          Platform '\(platform.name)' requires a target device t
          """
      case .failedToGenerateProvisioningProfile(let error):
        return error?.localizedDescription
          ?? "Failed to generate provisioning profile"
    }
  }
}
