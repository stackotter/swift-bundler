import Foundation
import PathKit
import ProjectSpec
import XcodeGenKit

/// A provisioning profile manager. Can locate existing provisioning profiles,
/// and generate new ones if required.
enum ProvisioningProfileManager {
  indirect enum Error: LocalizedError {
    case linuxNotSupported
    case failedToLocateLibraryDirectory(Swift.Error)
    case failedToEnumerateProfiles(directory: URL, Swift.Error)
    case failedToExtractProvisioningProfilePlist(URL, Swift.Error)
    case failedToDeserializeProvisioningProfile(URL, Swift.Error)
    case failedToParseBundleIdentifier(String)
    case failedToGenerateDummyXcodeproj(message: String?, Swift.Error?)
    case failedToRunXcodebuildAutoProvisioning(message: String?, ProcessError)
    case failedToParseXcodebuildOutput(_ message: String)
    case failedToLocateGeneratedProvisioningProfile(_ predictedLocation: URL)
    case failedToGetTeamIdentifier(CodeSignerError)
    case failedToLoadCertificates(CodeSignerError)

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
        case .failedToParseBundleIdentifier(let identifier):
          return "Failed to parse bundle identifier '\(identifier)'"
        case .failedToGenerateDummyXcodeproj(let message, let error):
          return """
            Failed to generate dummy xcodeproj for automatic provisioning: \
            \(message ?? error?.localizedDescription ?? "Unknown reason")
            """
        case .failedToRunXcodebuildAutoProvisioning(let message, let error):
          return """
            Failed to generate provisioning profile: \
            \(message ?? error.localizedDescription)
            """
        case .failedToParseXcodebuildOutput(let message):
          return "Failed to parse xcodebuild output: \(message)"
        case .failedToLocateGeneratedProvisioningProfile(let predictedLocation):
          return """
            Failed to locate generated provisioning profile. Expected it be \
            located at '\(predictedLocation.path)'
            """
        case .failedToGetTeamIdentifier(let error),
          .failedToLoadCertificates(let error):
          return error.localizedDescription
      }
    }
  }

  /// The path to the `openssl` tool.
  static let opensslToolPath = "/usr/bin/openssl"

  /// Ignore profiles within 12 hours of expiry.
  static let expirationBufferSeconds: Double = 60 * 12

  /// Attempts to locate or generate a provisioning profile suitable for the
  /// given configuration.
  static func locateOrGenerateSuitableProvisioningProfile(
    bundleIdentifier: String,
    deviceId: String,
    deviceOS: NonMacAppleOS,
    identity: CodeSigner.Identity
  ) -> Result<URL, Error> {
    locateSuitableProvisioningProfile(
      bundleIdentifier: bundleIdentifier,
      deviceId: deviceId,
      deviceOS: deviceOS,
      identity: identity
    ).andThen { provisioningProfile in
      if let provisioningProfile = provisioningProfile {
        return .success(provisioningProfile)
      }

      return CodeSigner.getTeamIdentifier(
        for: identity
      ).mapError { error in
        Error.failedToGetTeamIdentifier(error)
      }.andThen { teamIdentifier in
        generateProvisioningProfile(
          bundleIdentifier: bundleIdentifier,
          teamId: teamIdentifier,
          deviceId: deviceId,
          deviceOS: deviceOS
        )
      }
    }
  }

  /// Returns nil if the search went smoothly but returned not matching results.
  /// Always returns an error on Linux (not supported, yet...).
  static func locateSuitableProvisioningProfile(
    bundleIdentifier: String,
    deviceId: String,
    deviceOS: NonMacAppleOS,
    identity: CodeSigner.Identity
  ) -> Result<URL?, Error> {
    switch HostPlatform.hostPlatform {
      case .linux:
        return .failure(.linuxNotSupported)
      case .macOS:
        break
    }

    return CodeSigner.loadCertificates(for: identity)
      .mapError(Error.failedToLoadCertificates)
      .andThen { certificates in
        loadProvisioningProfiles().map { profiles in
          profiles.filter { (_, profile) in
            profile.provisionedDevices.contains(deviceId)
              && profile.expirationDate > Date().advanced(by: expirationBufferSeconds)
              && profile.platforms.contains(deviceOS.provisioningProfileName)
              && profile.suitable(forBundleIdentifier: bundleIdentifier)
              && profile.certificates.contains { certificate in
                certificates.contains { other in
                  other.serialNumber == certificate.serialNumber
                }
              }
          }.first?.0
        }
      }
  }

  static func loadProvisioningProfiles()
    -> Result<[(URL, ProvisioningProfile)], Error>
  {
    return locateProvisioningProfilesDirectory()
      .andThen { provisioningProfilesDirectory in
        FileManager.default.contentsOfDirectory(
          at: provisioningProfilesDirectory
        ).mapError { error in
          Error.failedToEnumerateProfiles(
            directory: provisioningProfilesDirectory,
            error
          )
        }
      }
      .andThen { provisioningProfiles in
        provisioningProfiles.filter { file in
          file.pathExtension == "mobileprovision"
        }.tryMap { profileFile in
          loadProvisioningProfile(profileFile).map { loadedProfile in
            (profileFile, loadedProfile)
          }
        }
      }
  }

  static func locateProvisioningProfilesDirectory() -> Result<URL, Error> {
    Result {
      try FileManager.default.url(
        for: .libraryDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: false
      )
    }
    .mapError(Error.failedToLocateLibraryDirectory)
    .map { libraryDirectory in
      libraryDirectory / "Developer/Xcode/UserData/Provisioning Profiles"
    }
  }

  static func loadProvisioningProfile(
    _ provisioningProfile: URL
  ) -> Result<ProvisioningProfile, Error> {
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

  static func generateProvisioningProfile(
    bundleIdentifier: String,
    teamId: String,
    deviceId: String,
    deviceOS: NonMacAppleOS
  ) -> Result<URL, Error> {
    log.info("Generating provisioning profile")

    let projectDirectory =
      FileManager.default.temporaryDirectory
      / "DummyProject-\(UUID().uuidString)"

    return generateDummyXcodeProject(
      projectDirectory: projectDirectory,
      bundleIdentifier: bundleIdentifier,
      teamId: teamId,
      deviceId: deviceId,
      deviceOS: deviceOS
    ).andThen { (xcodeprojFile, scheme) in
      Process.create(
        "xcodebuild",
        arguments: [
          "-project", xcodeprojFile.path,
          "-scheme", scheme,
          "-sdk", deviceOS.physicalPlatform.platform.sdkName,
          "-destination", "id=\(deviceId)",
          "-allowProvisioningUpdates",
          "-allowProvisioningDeviceRegistration",
          "build",
        ]
      ).getOutput(excludeStdError: false).mapError { error in
        guard
          case ProcessError.nonZeroExitStatusWithOutput(let data, _) = error,
          let output = String(data: data, encoding: .utf8)
        else {
          return .failedToRunXcodebuildAutoProvisioning(message: nil, error)
        }

        // Print the process' output to help users debug
        log.error("\(output)")

        let message: String?
        if output.contains("Failed Registering Bundle Identifier") {
          message = """
            Bundle identifier '\(bundleIdentifier)' is already taken. Change \
            your bundle identifier to a unique string and try again
            """
        } else {
          message = nil
        }

        return .failedToRunXcodebuildAutoProvisioning(message: message, error)
      }
    }.andThen { output in
      // We attempt to locate and parse the following part of xcodebuild's output;
      // ```
      //     Provisioning Profile: "iOS Team Provisioning Profile: *"
      //                           (c48afb72-3423-4345-bca7-c31232d09b64)
      // ```
      let lines = output.split(separator: "\n")
      guard
        let profileLineIndex = lines.firstIndex(where: { line in
          line.hasPrefix("    Provisioning Profile: ")
        }),
        profileLineIndex + 1 < lines.count
      else {
        let error = Error.failedToParseXcodebuildOutput(
          "Failed to locate generated provisioning profile ID"
        )
        log.debug("\(output)")
        return .failure(error)
      }

      let profileId = lines[profileLineIndex + 1]
        .trimmingCharacters(in: .whitespaces)
        .dropFirst()
        .dropLast()
      return .success(String(profileId))
    }.andThen { (profileId: String) in
      locateProvisioningProfilesDirectory().map { directory in
        directory / "\(profileId).mobileprovision"
      }
    }.andThenDoSideEffect { file in
      guard file.exists() else {
        return .failure(.failedToLocateGeneratedProvisioningProfile(file))
      }
      return .success()
    }
  }

  private static func generateDummyXcodeProject(
    projectDirectory: URL,
    bundleIdentifier: String,
    teamId: String,
    deviceId: String,
    deviceOS: NonMacAppleOS
  ) -> Result<(xcodeprojFile: URL, scheme: String), Error> {
    let sourcesDirectory = projectDirectory / "Sources"
    let infoPlistFile = sourcesDirectory / "Info.plist"
    let xcodeprojFile = projectDirectory / "Dummy.xcodeproj"

    return FileManager.default.createDirectory(at: sourcesDirectory)
      .mapError { error in
        .failedToGenerateDummyXcodeproj(
          message: "Failed to create sources directory at '\(sourcesDirectory.path)'",
          error
        )
      }
      .andThen { _ in
        generateDummyXcodeProjectSpec(
          bundleIdentifier: bundleIdentifier,
          teamId: teamId,
          deviceOS: deviceOS,
          projectDirectory: projectDirectory,
          sourcesDirectory: sourcesDirectory,
          infoPlistFile: infoPlistFile
        )
      }.andThenDoSideEffect { (_, productName) in
        // Write source files
        let dummySourceCode = "print(\"Hello, World!\")"
        let infoPlist: [String: Any] = [
          "CFBundleExecutable": productName,
          "CFBundleIdentifier": bundleIdentifier,
          "CFBundleInfoDictionaryVersion": "6.0",
          "CFBundleName": productName,
          "CFBundlePackageType": "APPL",
        ]

        return dummySourceCode.write(to: sourcesDirectory / "main.swift")
          .andThen { _ in
            return Result {
              try PropertyListSerialization.data(
                fromPropertyList: infoPlist,
                format: .xml,
                options: 0
              )
            }.andThen { data in
              data.write(to: infoPlistFile)
            }
          }.mapError { error in
            .failedToGenerateDummyXcodeproj(message: nil, error)
          }
      }.andThen { (project, productName) in
        guard let userName = ProcessInfo.processInfo.environment["LOGNAME"] else {
          let error = Error.failedToGenerateDummyXcodeproj(
            message: "Missing username (read from LOGNAME environment variable)",
            nil
          )
          return .failure(error)
        }

        let generator = ProjectGenerator(project: project)
        return Result {
          let xcodeProject = try generator.generateXcodeProject(
            in: Path(projectDirectory.path),
            userName: userName
          )
          let fileWriter = FileWriter(project: project)
          try fileWriter.writeXcodeProject(
            xcodeProject,
            to: Path(xcodeprojFile.path)
          )
        }.mapError { error in
          .failedToGenerateDummyXcodeproj(message: nil, error)
        }.replacingSuccessValue(with: (xcodeprojFile, productName))
      }
  }

  private static func generateDummyXcodeProjectSpec(
    bundleIdentifier: String,
    teamId: String,
    deviceOS: NonMacAppleOS,
    projectDirectory: URL,
    sourcesDirectory: URL,
    infoPlistFile: URL
  ) -> Result<(project: Project, productName: String), Error> {
    let bundleIdentifierParts = bundleIdentifier.split(separator: ".")
    let bundleIdentifierPrefix = bundleIdentifierParts.dropLast()
      .joined(separator: ".")

    guard
      let productName = bundleIdentifier.split(separator: ".").last
        .map(String.init)
    else {
      return .failure(.failedToParseBundleIdentifier(bundleIdentifier))
    }

    let target = Target(
      name: productName,
      type: .application,
      platform: deviceOS.xcodePlatform,
      settings: Settings(dictionary: ["DEVELOPMENT_TEAM": teamId]),
      sources: [TargetSource(path: sourcesDirectory.path)],
      info: Plist(path: infoPlistFile.path)
    )

    let project = Project(
      basePath: Path(projectDirectory.path),
      name: "Dummy",
      targets: [target],
      settings: Settings(dictionary: ["DEVELOPMENT_TEAM": teamId]),
      options: SpecOptions(bundleIdPrefix: bundleIdentifierPrefix)
    )

    return .success((project, productName))
  }
}

extension NonMacAppleOS {
  fileprivate var xcodePlatform: ProjectSpec.Platform {
    switch self {
      case .iOS:
        return .iOS
      case .tvOS:
        return .tvOS
      case .visionOS:
        return .visionOS
    }
  }
}
