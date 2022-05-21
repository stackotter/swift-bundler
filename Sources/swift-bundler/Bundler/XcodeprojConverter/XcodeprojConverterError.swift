import Foundation
import SwiftXcodeProj

/// An error returned by ``XcodeprojConverter``.
enum XcodeprojConverterError: LocalizedError {
  case failedToLoadXcodeProj(URL, Error)
  case unsupportedFilePathType(PBXSourceTree)
  case failedToEnumerateSources(target: String, Error)
  case failedToCreateTargetDirectory(target: String, URL, Error)
  case failedToCopyFile(source: URL, destination: URL, Error)
  case failedToCreatePackageManifest(URL, Error)
  case failedToCreateConfigurationFile(URL, Error)
  case directoryAlreadyExists(URL)
  case invalidBuildFile(PBXBuildFile)
  case failedToLoadXcodeWorkspace(URL, Error)
  case failedToGetRelativePath(PBXFileElement, Error?)
  case failedToCreateAppConfiguration(target: String, AppConfigurationError)

  var errorDescription: String? {
    switch self {
      case .failedToLoadXcodeProj(let file, let error):
        return "Failed to load xcodeproj from '\(file.relativePath)': \(error.localizedDescription)"
      case .unsupportedFilePathType(let pathType):
        return "Unsupported file path type '\(pathType.description)'"
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
      case .invalidBuildFile(let file):
        return "Encountered invalid build file with uuid '\(file.uuid)'"
      case .failedToLoadXcodeWorkspace(let file, let error):
        return "Failed to load xcworkspace from '\(file.relativePath)': \(error.localizedDescription)"
      case .failedToGetRelativePath(let file, _):
        return "Failed to get relative path of '\(file.name ?? "unknown file")'"
      case .failedToCreateAppConfiguration(let target, let error):
        return "Failed to create app configuration for '\(target)': \(error.localizedDescription)"
    }
  }
}
