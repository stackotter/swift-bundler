import Foundation

/// An error returned by ``CodeSigner``.
enum CodeSignerError: LocalizedError {
  case failedToEnumerateIdentities(ProcessError)
  case failedToParseIdentityList(Error)
  case failedToRunCodesignTool(ProcessError)
  case failedToWriteEntitlements(Error)
  case failedToVerifyProvisioningProfile(ProcessError)
  case failedToDeserializeProvisioningProfile(Error)
  case provisioningProfileMissingTeamIdentifier

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
      case .failedToVerifyProvisioningProfile:
        return "Failed to verify provisioning profile"
      case .failedToDeserializeProvisioningProfile:
        return "Failed to deserialize provisioning profile plist"
      case .provisioningProfileMissingTeamIdentifier:
        return "The supplied provisioning profile is missing the 'TeamIdentifier' entry"
    }
  }
}
