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
  case failedToLocateSigningCertificate(CodeSigner.Identity, Error)
  case failedToParseSigningCertificate(pem: String, Error)
  case signingCertificateMissingTeamIdentifier(CodeSigner.Identity)
  case identityShortNameNotMatched(String)
  case failedToLocateLatestCertificate(CodeSigner.Identity)

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
      case .failedToLocateSigningCertificate(let identity, let error):
        return """
          Failed to locate signing certificate for identity \
          '\(identity.name)': \(error.localizedDescription)
          """
      case .failedToParseSigningCertificate(_, let error):
        return "Failed to parse signing certificate: \(error.localizedDescription)"
      case .signingCertificateMissingTeamIdentifier(let identity):
        return """
          Failed to locate team identifier in signing certificate for \
          identity '\(identity.name)'
          """
      case .identityShortNameNotMatched(let shortName):
        return """
          Identity short name '\(shortName)' didn't match any known identities. \
          Run 'swift bundler list-identities' to list available identities.
          """
      case .failedToLocateLatestCertificate(let identity):
        return """
          Failed to locate latest signing certificate for identity \
          '\(identity.name)'
          """
    }
  }
}
