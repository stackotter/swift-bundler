import Foundation
import Version
import ErrorKit

/// An error returned by ``Templater``.
enum TemplaterError: Throwable {
  case packageDirectoryAlreadyExists(URL)
  case failedToCloneTemplateRepository(Process.Error)
  case failedToGetApplicationSupportDirectory(SystemError)
  case cannotCreatePackageFromBaseTemplate
  case noSuchTemplate(String)
  case failedToCreateOutputDirectory(URL, Error)
  case failedToDecodeTemplateManifest(template: String, manifest: URL, Error)
  case failedToReadTemplateManifest(template: String, manifest: URL, Error)
  case templateDoesNotSupportInstalledSwiftVersion(
    template: String, version: Version, minimumSupportedVersion: Version
  )
  case failedToEnumerateTemplateContents(template: String)
  case failedToReadFile(template: String, file: URL, Error)
  case failedToGetRelativePath(file: URL, base: URL)
  case failedToWriteToOutputFile(file: URL, Error)
  case failedToCreateBareMinimumPackage(SwiftPackageManagerError)
  case failedToEnumerateTemplates(Error)
  case failedToPullLatestTemplates(Process.Error)
  case failedToEnumerateOutputFiles
  case failedToUpdateIndentationStyle(directory: URL, Error)
  case failedToCheckSwiftVersion(SwiftPackageManagerError)
  case failedToCreateConfigurationFile(PackageConfiguration, URL, Error)
  case missingVSCodeOverlay

  var userFriendlyMessage: String {
    switch self {
      case .packageDirectoryAlreadyExists(let directory):
        return "A directory already exists at '\(directory.relativePath)'"
      case .failedToCloneTemplateRepository(let processError):
        return
          "Failed to clone the default template repository from '\(Templater.defaultTemplateRepository)': \(processError.localizedDescription)"
      case .failedToGetApplicationSupportDirectory(let error):
        return error.localizedDescription
      case .cannotCreatePackageFromBaseTemplate:
        return "Cannot create a package from the 'Base' template"
      case let .noSuchTemplate(template):
        return "The '\(template)' template does not exist"
      case .failedToCreateOutputDirectory(let directory, _):
        return "Failed to create package directory at '\(directory.relativePath)'"
      case .failedToDecodeTemplateManifest(let template, _, _):
        return Output {
          "Failed to decode the manifest for the '\(template)' template"
          ""
          Section("Troubleshooting") {
            "Have you updated your templates recently?"
            ExampleCommand("swift bundler templates update")
          }
        }.description
      case .failedToReadTemplateManifest(let template, _, _):
        return "Failed to read the contents of the manifest for the '\(template)' template"
      case .templateDoesNotSupportInstalledSwiftVersion(
        let template, let version, let minimumSupportedVersion):
        let tip = "Provide the '-f' flag to create the package anyway"
        let version = version.description
        let minimumVersion = minimumSupportedVersion.description
        return
          "The '\(template)' template supports a minimum Swift version of \(minimumVersion) but \(version) is installed. \(tip)"
      case .failedToEnumerateTemplateContents(let template):
        return "Failed to enumerate the contents of the '\(template)' template"
      case .failedToReadFile(let template, let file, _):
        return "Failed to read the file '\(file.relativePath)' from the '\(template)' template"
      case .failedToGetRelativePath(let file, let base):
        return "Failed to get relative path from '\(file.relativePath)' to '\(base.relativePath)'"
      case .failedToWriteToOutputFile(let file, _):
        return "Failed to write to the output file at '\(file.relativePath)'"
      case .failedToCreateBareMinimumPackage(let error):
        return "Failed to create package: \(error.localizedDescription)"
      case .failedToEnumerateTemplates:
        return "Failed to enumerate templates"
      case .failedToPullLatestTemplates(let processError):
        return
          "Failed to pull the latest templates from '\(Templater.defaultTemplateRepository)': \(processError)"
      case .failedToEnumerateOutputFiles:
        return "Failed to enumerate the files in the output directory"
      case .failedToUpdateIndentationStyle(let directory, _):
        return
          "Failed to update the indentation style of the package in '\(directory.relativePath)'"
      case .failedToCheckSwiftVersion(let swiftPackageManagerError):
        return "Failed to check Swift version: \(swiftPackageManagerError.localizedDescription)"
      case .failedToCreateConfigurationFile(_, let file, _):
        return "Failed to create configuration file at '\(file.relativePath)'"
      case .missingVSCodeOverlay:
        return Output {
          "Missing VSCode overlay."
          ""
          Section("Troubleshooting") {
            "Your templates may be outdated"
            ExampleCommand("swift bundler templates update")
          }
        }.description
    }
  }
}
