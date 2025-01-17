import Foundation

/// An error returned by ``CodeSigner``.
enum CodeSignerError: LocalizedError {
  case failedToEnumerateIdentities(ProcessError)
  case failedToParseIdentityList(Error)
  case failedToRunCodesignTool(ProcessError)
  case failedToWriteEntitlements(Error)
  case failedToLoadProvisioningProfile(URL, ProvisioningProfileManager.Error)
  case provisioningProfileMissingTeamIdentifier
  case failedToEnumerateDynamicLibraries(Error)

  var errorDescription: String? {
    switch self {
      case .failedToEnumerateIdentities(let error):
        return "Failed to enumerate code signing identities: \(error)"
      case .failedToParseIdentityList(let error):
        return "Failed to parse identity list: \(error)"
      case .failedToRunCodesignTool(let error):
        return "Failed to run 'codesign' command: \(error)"
      case .failedToWriteEntitlements:
        return "Failed to write entitlements"
      case .failedToLoadProvisioningProfile(let file, let error):
        return """
          Failed to load '\(file.path)': \(error.localizedDescription)
          """
      case .provisioningProfileMissingTeamIdentifier:
        return "The supplied provisioning profile is missing the 'TeamIdentifier' entry"
      case .failedToEnumerateDynamicLibraries:
        return "Failed to enumerate dynamic libraries"
    }
  }
}
