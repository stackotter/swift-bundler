import Foundation

#if SUPPORT_XCODEPROJ
  import XcodeProj
#endif

/// An error returned by ``XcodeprojConverter``.
enum XcodeprojConverterError: LocalizedError {
  case hostPlatformNotSupported
  case failedToLoadXcodeProj(URL, Error)
  case failedToEnumerateSources(target: String, Error)
  case failedToCreateTargetDirectory(target: String, URL, Error)
  case failedToCopyFile(source: URL, destination: URL, Error)
  case failedToCreatePackageManifest(URL, Error)
  case failedToCreateConfigurationFile(URL, Error)
  case directoryAlreadyExists(URL)
  case failedToLoadXcodeWorkspace(URL, Error)
  case failedToCreateAppConfiguration(target: String, AppConfigurationError)

  #if SUPPORT_XCODEPROJ
    case unsupportedFilePathType(PBXSourceTree)
    case invalidBuildFile(PBXBuildFile)
    case failedToGetRelativePath(PBXFileElement, Error?)
  #endif

  var errorDescription: String? {
    switch self {
      case .hostPlatformNotSupported:
        return """
          Xcodeproj integration isn't supported on \
          \(HostPlatform.hostPlatform.platform.name)
          """
      case .failedToLoadXcodeProj(let file, let error):
        return "Failed to load xcodeproj from '\(file.relativePath)': \(error.localizedDescription)"
      case .failedToEnumerateSources(let target, _):
        return "Failed to enumerate sources for target '\(target)'"
      case .failedToCreateTargetDirectory(let target, _, let error):
        return "Failed to create directory for target '\(target)': \(error.localizedDescription)"
      case .failedToCopyFile(_, _, let error):
        return "Failed to copy file: \(error)"
      case .failedToCreatePackageManifest(_, let error):
        return "Failed to create package manifest: \(error.localizedDescription)"
      case .failedToCreateConfigurationFile(_, let error):
        return "Failed to create configuration file: \(error.localizedDescription)"
      case .directoryAlreadyExists(let directory):
        return "Directory already exists at '\(directory.relativePath)'"
      case .failedToLoadXcodeWorkspace(let file, let error):
        return
          "Failed to load xcworkspace from '\(file.relativePath)': \(error.localizedDescription)"
      case .failedToCreateAppConfiguration(let target, let error):
        return "Failed to create app configuration for '\(target)': \(error.localizedDescription)"

      #if SUPPORT_XCODEPROJ
        case .unsupportedFilePathType(let pathType):
          return "Unsupported file path type '\(pathType.description)'"
        case .invalidBuildFile(let file):
          return "Encountered invalid build file with uuid '\(file.uuid)'"
        case .failedToGetRelativePath(let file, _):
          return "Failed to get relative path of '\(file.name ?? "unknown file")'"
      #endif
    }
  }
}
