import Foundation
import ErrorKit

extension ProvisioningProfileManager {
  typealias Error = RichError<ErrorMessage>

  /// An error message related to ``ProvisioningProfileManager``.
  enum ErrorMessage: Throwable {
    case hostPlatformNotSupported
    case failedToLocateLibraryDirectory
    case failedToEnumerateProfiles(directory: URL)
    case failedToExtractProvisioningProfilePlist(URL)
    case failedToDeserializeProvisioningProfile(URL)
    case failedToParseBundleIdentifier(String)
    case failedToGenerateDummyXcodeproj(message: String?)
    case failedToRunXcodebuildAutoProvisioning(message: String?)
    case failedToParseXcodebuildOutput(_ message: String)
    case failedToLocateGeneratedProvisioningProfile(_ predictedLocation: URL)

    var userFriendlyMessage: String {
      switch self {
        case .hostPlatformNotSupported:
          return """
            Provisioning profiles aren't supported on \
            \(HostPlatform.hostPlatform.platform.name)
            """
        case .failedToLocateLibraryDirectory:
          return "Failed to locate user Developer directory"
        case .failedToEnumerateProfiles(let directory):
          return "Failed to enumerate provisioning profiles in '\(directory.path)'"
        case .failedToExtractProvisioningProfilePlist(let file):
          return "Failed to extract plist data from '\(file.path)'"
        case .failedToDeserializeProvisioningProfile(let file):
          return "Failed to deserialize plist data from '\(file.path)'"
        case .failedToParseBundleIdentifier(let identifier):
          return "Failed to parse bundle identifier '\(identifier)'"
        case .failedToGenerateDummyXcodeproj(let message):
          return """
            Failed to generate dummy xcodeproj for automatic provisioning: \
            \(message ?? "Unknown reason")
            """
        case .failedToRunXcodebuildAutoProvisioning(let message):
          return """
            Failed to generate provisioning profile: \
            \(message ?? "Unknown reason")
            """
        case .failedToParseXcodebuildOutput(let message):
          return "Failed to parse xcodebuild output: \(message)"
        case .failedToLocateGeneratedProvisioningProfile(let predictedLocation):
          return """
            Failed to locate generated provisioning profile. Expected it be \
            located at '\(predictedLocation.path)'
            """
      }
    }
  }
}
