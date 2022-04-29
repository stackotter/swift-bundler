import Foundation

/// An error returned by ``IOSBundler``.
enum IOSBundlerError: LocalizedError {
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
  case invalidArchitecture(String)
  case invalidBuildConfiguration(String)
  case invalidPlatform(String)
  case failedToEnumerateProvisioningProfiles(Error)
  case failedToLocateProvisioningProfile
  case failedToCopyProvisioningProfile(Error)

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
      case .invalidAppIconFile(let file):
        return "Invalid app icon file, must be 'png' or 'icns', got '\(file.relativePath)'"
      case .invalidArchitecture(let arch):
        let validArchitectures = BuildArchitecture.possibleValuesString
        return "'\(arch)' is not a valid architecture. Should be in \(validArchitectures)"
      case .invalidBuildConfiguration(let configuration):
        let validConfigurations = BuildConfiguration.possibleValuesString
        return "'\(configuration)' is not a valid configuration. Should be in \(validConfigurations)"
      case .invalidPlatform(let platform):
        let validPlatforms = Platform.possibleValuesString
        return "'\(platform)' is not a valid platform. Should be in \(validPlatforms)"
      case .failedToEnumerateProvisioningProfiles:
        return "Failed to enumerate provisioning profiles"
      case .failedToLocateProvisioningProfile:
        return "Failed to locate valid provisioning profile"
      case .failedToCopyProvisioningProfile:
        return "Failed to copy provisioning profile to output bundle"
    }
  }
}
