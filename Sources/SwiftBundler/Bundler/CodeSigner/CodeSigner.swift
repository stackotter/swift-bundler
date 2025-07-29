import Foundation
import Parsing
import SwiftASN1
import X509

/// A utility for codesigning Darwin application bundles
enum CodeSigner {
  /// The path to the `codesign` tool.
  static let codesignToolPath = "/usr/bin/codesign"
  /// The path to the `security` tool.
  static let securityToolPath = "/usr/bin/security"

  /// An identity that can be used to codesign a bundle.
  struct Identity: CustomStringConvertible {
    /// The identity's id.
    var id: String
    /// The identity's display name.
    var name: String

    var description: String {
      "'\(name)' (\(id))"
    }
  }

  /// Generates an iOS entitlements file.
  /// - Parameters:
  ///   - outputFile: The destination for the generated entitlements file.
  ///   - bundle: The app bundle to sign.
  ///   - identityId: The id of the codesigning identity to use.
  ///   - bundleIdentifier: The identifier of the app bundle.
  /// - Returns: A failure if the `codesign` command fails to run.
  static func generateEntitlementsFile(
    at outputFile: URL,
    for bundle: URL,
    identityId: String,
    bundleIdentifier: String
  ) async throws(Error) {
    let teamIdentifier = try await extractTeamIdentifier(from: bundle)

    let entitlementsContent = generateEntitlementsContent(
      teamIdentifier: teamIdentifier,
      bundleIdentifier: bundleIdentifier
    )

    do {
      try entitlementsContent.write(
        to: outputFile,
        atomically: false,
        encoding: .utf8
      )
    } catch {
      throw Error(.failedToWriteEntitlements, cause: error)
    }
  }

  /// Signs a Darwin app bundle.
  ///
  /// If no entitlements are provided and the platform requires provisioning
  /// profiles, some basic entitlements get automatically generated. Otherwise
  /// the application bundle will fail to verify.
  /// - Parameters:
  ///   - bundle: The app bundle to sign.
  ///   - identityId: The id of the codesigning identity to use.
  ///   - bundleIdentifier: The app's bundle identifier.
  ///   - platform: The target platform getting built for.
  ///   - entitlements: The app's entitlements file.
  /// - Returns: A failure if the `codesign` command fails to run.
  static func signAppBundle(
    bundle: URL,
    identityId: String,
    bundleIdentifier: String,
    platform: ApplePlatform,
    entitlements: URL?
  ) async throws(Error) {
    log.info("Codesigning app bundle")

    let librariesDirectory = bundle.appendingPathComponent("Libraries")
    if FileManager.default.itemExists(at: librariesDirectory, withType: .directory) {
      let contents: [URL]
      do {
        contents = try FileManager.default.contentsOfDirectory(
          at: librariesDirectory,
          includingPropertiesForKeys: nil
        )
      } catch {
        throw Error(.failedToEnumerateDynamicLibraries, cause: error)
      }

      for file in contents where file.pathExtension == "dylib" {
        try await sign(file: file, identityId: identityId)
      }
    }

    // Generate entitlements file if required by platform and not provided
    let entitlementsFile: URL?
    if let entitlements = entitlements {
      entitlementsFile = entitlements
    } else if platform.requiresProvisioningProfiles {
      let file =
        FileManager.default.temporaryDirectory
        / "\(UUID().uuidString).xcent"

      entitlementsFile = file

      try await CodeSigner.generateEntitlementsFile(
        at: file,
        for: bundle,
        identityId: identityId,
        bundleIdentifier: bundleIdentifier
      )
    } else {
      entitlementsFile = nil
    }

    try await sign(
      file: bundle,
      identityId: identityId,
      entitlements: entitlementsFile
    )
  }

  /// Signs a binary or app bundle.
  /// - Parameters:
  ///   - bundle: The binary or app bundle to sign.
  ///   - identityId: The id of the codesigning identity to use.
  ///   - entitlements: The entitlements to give the file (only valid for app bundles).
  /// - Returns: A failure if the `codesign` command fails.
  static func sign(
    file: URL,
    identityId: String,
    entitlements: URL? = nil
  ) async throws(Error) {
    let entitlementArguments: [String]
    if let entitlements = entitlements {
      entitlementArguments = [
        "--entitlements", entitlements.path,
        "--generate-entitlement-der",
      ]
    } else {
      entitlementArguments = []
    }

    let arguments =
      entitlementArguments + [
        "--force", "--deep",
        "--sign", identityId,
        file.path,
      ]

    do {
      try await Process.create(
        codesignToolPath,
        arguments: arguments
      ).runAndWait()
    } catch {
      throw Error(.failedToRunCodesignTool, cause: error)
    }
  }

  /// Signs a binary or app bundle using ad-hoc signing.
  /// - Parameter file: The file to sign.
  /// - Returns: A failure if the `codesign` command fails.
  static func signAdHoc(file: URL) async throws(Error) {
    do {
      try await Process.create(
        codesignToolPath,
        arguments: ["--force", "-s", "-", file.path]
      ).runAndWait()
    } catch {
      throw Error(.failedToRunCodesignTool, cause: error)
    }
  }

  /// Enumerates the user's available codesigning identities.
  /// - Returns: An array of identities, or a failure if the `security` command fails or produces invalid output.
  static func enumerateIdentities() async throws(Error) -> [Identity] {
    let process = Process.create(
      securityToolPath,
      arguments: ["find-identity", "-pcodesigning", "-v"]
    )

    let output: String
    do {
      output = try await process.getOutput()
    } catch {
      throw Error(.failedToEnumerateIdentities, cause: error)
    }
    // Example input: `52635337831A02427192D4FC5EC8528323456F17 "Apple Development: stackotter@stackotter.dev (LK3JHG2345)"`
    let identityParser = Parse {
      PrefixThrough(") ")
      PrefixUpTo(" ").map { (id: Substring) in
        String(id)
      }
      " "
      OneOf {
        PrefixUpTo("\n")
        Rest<Substring>()
      }.map { (substring: Substring) -> String in
        // Remove quotation marks
        let withoutQuotationMarks: Substring = substring.dropFirst().dropLast()
        return String(withoutQuotationMarks)
      }
    }.map { (_: Substring, id: String, name: String) in
      return Identity(id: id, name: name)
    }

    let identityListParser = Parse {
      Many {
        identityParser
      }
      Rest<Substring>()
    }.map { (identities: [Identity], _: Substring) in
      return identities
    }

    let identities: [Identity]
    do {
      identities = try identityListParser.parse(output)
    } catch {
      throw Error(.failedToParseIdentityList, cause: error)
    }

    return identities
  }

  /// Resolves a short-hand identity name. Can either be a full identity id or
  /// a substring of an identity's display name.
  static func resolveIdentity(
    shortName: String
  ) async throws(Error) -> Identity {
    let identities = try await enumerateIdentities()
    let matchingIdentities = identities.filter { identity in
      identity.id == shortName || identity.name.contains(shortName)
    }
    guard let identity = matchingIdentities.first else {
      throw Error(.identityShortNameNotMatched(shortName))
    }

    if matchingIdentities.count > 1 {
      log.warning(
        "Multiple identities matched short name '\(shortName)', using \(identity)"
      )
    }

    return identity
  }

  static func loadCertificates(
    for identity: Identity
  ) async throws(Error) -> [Certificate] {
    let output: String
    do {
      output = try await Process.create(
        securityToolPath,
        arguments: [
          "find-certificate", "-c", identity.name, "-p", "-a",
        ]
      ).getOutput()
    } catch {
      throw Error(.failedToLocateSigningCertificate(identity), cause: error)
    }

    let separator = "-----BEGIN CERTIFICATE-----\n"
    let certificates = output.components(separatedBy: separator).filter { part in
      !part.isEmpty
    }.map { part in
      // Add separator back to each certificate
      String(separator + part)
    }

    return try certificates.map { (certificatePEM) throws(Error) in
      do {
        return try Certificate(pemEncoded: certificatePEM)
      } catch {
        throw Error(
          .failedToParseSigningCertificate(pem: certificatePEM),
          cause: error
        )
      }
    }
  }

  static func getLatestCertificate(
    for identity: Identity
  ) async throws(Error) -> Certificate {
    let now = Date()
    let certificates = try await loadCertificates(for: identity)

    guard
      let latest = certificates.filter({ certificate in
        certificate.notValidAfter > now
      }).sorted(by: { first, second in
        first.notValidBefore > second.notValidBefore
      }).first
    else {
      throw Error(.failedToLocateLatestCertificate(identity))
    }

    return latest
  }

  static func getTeamIdentifier(for identity: Identity) async throws(Error) -> String {
    let certificate = try await getLatestCertificate(for: identity)

    for element in certificate.subject {
      for attribute in element {
        guard
          attribute.type == ASN1ObjectIdentifier.RDNAttributeType.organizationalUnitName
        else {
          continue
        }
        return attribute.value.description
      }
    }

    throw Error(.signingCertificateMissingTeamIdentifier(identity))
  }

  static func extractTeamIdentifier(from bundle: URL) async throws(Error) -> String {
    let provisioningProfile = bundle / "embedded.mobileprovision"
    let profile: ProvisioningProfile
    do {
      profile = try await ProvisioningProfileManager
        .loadProvisioningProfile(provisioningProfile)
    } catch {
      throw Error(.failedToLoadProvisioningProfile(provisioningProfile), cause: error)
    }

    guard let identifier = profile.teamIdentifierArray.first else {
      throw Error(.provisioningProfileMissingTeamIdentifier)
    }

    return identifier
  }

  /// Generates the contents of an entitlements file.
  static func generateEntitlementsContent(
    teamIdentifier: String,
    bundleIdentifier: String
  ) -> String {
    return """
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
      	<key>application-identifier</key>
      	<string>\(teamIdentifier).\(bundleIdentifier)</string>
      	<key>com.apple.developer.team-identifier</key>
      	<string>\(teamIdentifier)</string>
      	<key>get-task-allow</key>
      	<true/>
      </dict>
      </plist>
      """
  }
}
