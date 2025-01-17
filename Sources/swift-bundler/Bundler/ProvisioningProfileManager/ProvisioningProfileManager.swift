import Foundation

/// A provisioning profile manager. Can locate existing provisioning profiles,
/// and generate new ones if required.
enum ProvisioningProfileManager {
  enum Error: LocalizedError {
    case linuxNotSupported
    case failedToLocateLibraryDirectory(Swift.Error)
    case failedToEnumerateProfiles(directory: URL, Swift.Error)
    case failedToExtractProvisioningProfilePlist(URL, Swift.Error)
    case failedToDeserializeProvisioningProfile(URL, Swift.Error)

    var errorDescription: String? {
      switch self {
        case .linuxNotSupported:
          return "Provisioning profiles aren't supported on Linux"
        case .failedToLocateLibraryDirectory(let error):
          return "Failed to locate user Developer directory: \(error.localizedDescription)"
        case .failedToEnumerateProfiles(let directory, let error):
          return """
            Failed to enumerate provisioning profiles in '\(directory.path)': \
            \(error.localizedDescription)
            """
        case .failedToExtractProvisioningProfilePlist(let file, let error):
          return """
            Failed to extract plist data from '\(file.path)': \
            \(error.localizedDescription)
            """
        case .failedToDeserializeProvisioningProfile(let file, let error):
          return """
            Failed to deserialize plist data from '\(file.path)': \
            \(error.localizedDescription)
            """
      }
    }
  }

  /// The path to the `openssl` tool.
  static let opensslToolPath = "/usr/bin/openssl"

  /// Ignore profiles within 12 hours of expiry.
  static let expirationBufferSeconds: Double = 60 * 12

  /// Returns nil if the search went smoothly but returned not matching results.
  /// Always returns an error on Linux (not supported, yet...).
  static func locateSuitableProvisioningProfile(
    bundleIdentifier: String,
    deviceId: String,
    deviceOS: NonMacAppleOS,
    identity: String
  ) -> Result<URL?, Error> {
    switch HostPlatform.hostPlatform {
      case .linux:
        return .failure(.linuxNotSupported)
      case .macOS:
        break
    }

    return loadProvisioningProfiles().map { profiles in
      profiles.filter { (_, profile) in
        profile.provisionedDevices.contains(deviceId)
          && profile.expirationDate > Date().advanced(by: expirationBufferSeconds)
          && profile.platforms.contains(deviceOS.provisioningProfileName)
          && profile.suitable(forBundleIdentifier: bundleIdentifier)
      }.first?.0
    }
  }

  static func loadProvisioningProfiles()
    -> Result<[(URL, ProvisioningProfile)], Error>
  {
    return Result {
      try FileManager.default.url(
        for: .libraryDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: false
      )
    }
    .mapError(Error.failedToLocateLibraryDirectory)
    .andThen { libraryDirectory in
      let provisioningProfilesDirectory =
        libraryDirectory / "Developer/Xcode/UserData/Provisioning Profiles"

      return FileManager.default.contentsOfDirectory(
        at: provisioningProfilesDirectory
      ).mapError { error in
        Error.failedToEnumerateProfiles(
          directory: provisioningProfilesDirectory,
          error
        )
      }
    }
    .andThen { provisioningProfiles in
      provisioningProfiles.tryMap { profileFile in
        loadProvisioningProfile(profileFile).map { loadedProfile in
          (profileFile, loadedProfile)
        }
      }
    }
  }

  static func loadProvisioningProfile(
    _ provisioningProfile: URL
  ) -> Result<ProvisioningProfile, Error> {
    // security find-certificate -c "Apple Development: stackotter@stackotter.dev (HU3VJ82X52)" -p | openssl x509 -noout -subject

    return Process.create(
      opensslToolPath,
      arguments: [
        "smime", "-verify",
        "-in", provisioningProfile.path,
        "-noverify",
        "-inform", "der",
      ]
    )
    .getOutput(excludeStdError: true)
    .mapError { error in
      .failedToExtractProvisioningProfilePlist(provisioningProfile, error)
    }
    .andThen { plistContent in
      Result {
        try PropertyListDecoder().decode(
          ProvisioningProfile.self,
          from: Data(plistContent.utf8)
        )
      }.mapError { error in
        .failedToDeserializeProvisioningProfile(
          provisioningProfile,
          error
        )
      }
    }
  }
}
