import Foundation

/// An error returned by ``Templater``.
enum TemplaterError: LocalizedError {
  case packageDirectoryAlreadyExists(URL)
  case failedToCloneTemplateRepository(ProcessError)
  case failedToGetApplicationSupportDirectory(Error)
  case cannotCreatePackageFromBaseTemplate
  case noSuchTemplate(String)
  case failedToCreateOutputDirectory(URL, Error)
  case failedToDecodeTemplateManifest(template: String, manifest: URL, Error)
  case failedToReadTemplateManifest(template: String, manifest: URL, Error)
  case templateDoesNotSupportCurrentPlatform(template: String, platform: String, supportedPlatforms: [String])
  case failedToEnumerateTemplateContents(template: String)
  case failedToReadFile(template: String, file: URL, Error)
  case failedToGetRelativePath(file: URL, base: URL)
  case failedToWriteToOutputFile(file: URL, Error)
  case failedToCreateSkeletonPackage(SwiftPackageManagerError)
  case failedToEnumerateTemplates(Error)
  case failedToPullLatestTemplates(ProcessError)
  case failedToEnumerateOutputFiles
  case failedToUpdateIndentationStyle(directory: URL, Error)

  var errorDescription: String? {
    switch self {
      case .packageDirectoryAlreadyExists(let directory):
        return "A directory already exists at '\(directory.relativePath)'"
      case .failedToCloneTemplateRepository(let processError):
        return "Failed to clone the default template repository from '\(Templater.defaultTemplateRepository)': \(processError.localizedDescription)"
      case .failedToGetApplicationSupportDirectory:
        return "Failed to get Swift Bundler's application support directory"
      case .cannotCreatePackageFromBaseTemplate:
        return "Cannot create a package from the 'Base' template"
      case let .noSuchTemplate(template):
        return "The '\(template)' template does not exist"
      case .failedToCreateOutputDirectory(let directory, _):
        return "Failed to create package directory at '\(directory.relativePath)'"
      case .failedToDecodeTemplateManifest(let template, _, _):
        return "Failed to decode the manifest for the '\(template)' template"
      case .failedToReadTemplateManifest(let template, _, _):
        return "Failed to read the contents of the manifest for the '\(template)' template"
      case .templateDoesNotSupportCurrentPlatform(let template, let platform, let supportedPlatforms):
        let tip = "Provide the '-f' flag to create package anyway"
        let supportedPlatforms = "Supported platforms: [\(supportedPlatforms.joined(separator: ", "))]"
        return "The '\(template)' template does not support the current platform ('\(platform)'). \(supportedPlatforms). \(tip)"
      case .failedToEnumerateTemplateContents(let template):
        return "Failed to enumerate the contents of the '\(template)' template"
      case .failedToReadFile(let template, let file, _):
        return "Failed to read the file '\(file.relativePath)' from the '\(template)' template"
      case .failedToGetRelativePath(let file, let base):
        return "Failed to get relative path from '\(file.relativePath)' to '\(base.relativePath)'"
      case .failedToWriteToOutputFile(let file, _):
        return "Failed to write to the output file at '\(file.relativePath)'"
      case .failedToCreateSkeletonPackage(let error):
        return "Failed to create the package from the 'Skeleton' template: \(error.localizedDescription)"
      case .failedToEnumerateTemplates:
        return "Failed to enumerate templates"
      case .failedToPullLatestTemplates(let processError):
        return "Failed to pull the latest templates from '\(Templater.defaultTemplateRepository)': \(processError.localizedDescription)"
      case .failedToEnumerateOutputFiles:
        return "Failed to enumerate the files in the output directory"
      case .failedToUpdateIndentationStyle(let directory, _):
        return "Failed to update the indentation style of the package in '\(directory.relativePath)'"
    }
  }
}
