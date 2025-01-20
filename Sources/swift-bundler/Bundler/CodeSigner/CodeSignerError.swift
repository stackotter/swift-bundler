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
  case failedToLocateSigningCertificate(fullIdentityName: String, Error)
  case failedToParseSigningCertificate(Error)
  case signingCertificateMissingTeamIdentifier(fullIdentityName: String)
  case identityShortNameNotMatched(String)

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
      case .failedToLocateSigningCertificate(let fullIdentityName, let error):
        return """
          Failed to locate signing certificate for identity \
          '\(fullIdentityName)': \(error.localizedDescription)
          """
      case .failedToParseSigningCertificate(let error):
        return "Failed to parse signing certificate: \(error.localizedDescription)"
      case .signingCertificateMissingTeamIdentifier(let fullIdentityName):
        return """
          Failed to locate team identifier in signing certificate for \
          identity '\(fullIdentityName)'
          """
      case .identityShortNameNotMatched(let shortName):
        return """
          Identity short name '\(shortName)' didn't match any known identities. \
          Run 'swift bundler list-identities' to list available identities.
          """
    }
  }
}
