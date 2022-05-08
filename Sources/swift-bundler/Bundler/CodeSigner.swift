import Foundation
import Parsing

/// A utility for codesigning Darwin application bundles
enum CodeSigner {
  /// An identity that can be used to codesign a bundle.
  struct Identity {
    /// The identity's id.
    var id: String
    /// The identity's display name.
    var name: String
  }
  
  /// Signs an iOS app bundle and generates entitlements file.
  /// - Parameters:
  ///   - bundle: The app bundle to sign.
  ///   - identityId: The id of the codesigning identity to use.
  ///   - bundleIdentifier: The identifier of the app bundle.
  /// - Returns: A failure if the `codesign` command fails to run.
  static func signWithGeneratedEntitlements(bundle: URL, identityId: String, bundleIdentifier: String) -> Result<Void, CodeSignerError> {
    log.info("Codesigning executable")
    let entitlements = bundle.deletingLastPathComponent().appendingPathComponent("entitlements.xcent")

    return getTeamIdentifier(from: bundle).map { teamIdentifier -> String in
      generateEntitlementsContent(
        teamIdentifier: teamIdentifier,
        bundleIdentifier: bundleIdentifier
      )
    }.flatMap { entitlementsContent in
      do {
        try entitlementsContent.write(to: entitlements, atomically: false, encoding: .utf8)
      } catch {
        return .failure(.failedToWriteEntitlements(error))
      }

      return sign(bundle: bundle, identityId: identityId, entitlements: entitlements)    
    }
  }

  /// Signs a Darwin app bundle.
  /// - Parameters:
  ///   - bundle: The app bundle to sign.
  ///   - identityId: The id of the codesigning identity to use.
  ///   - entitlements: The app's entitlements file.
  /// - Returns: A failure if the `codesign` command fails to run.
  static func sign(bundle: URL, identityId: String, entitlements: URL? = nil) -> Result<Void, CodeSignerError> {
    let entitlementArguments: [String]
    if let entitlements = entitlements {
      entitlementArguments = [
        "--entitlements", entitlements.path,
        "--generate-entitlement-der"
      ]
    } else {
      entitlementArguments = []
    }

    let arguments = entitlementArguments + [
      "--force", "--deep",
      "--sign", identityId,
      bundle.path
    ]

    let process = Process.create(
      "/usr/bin/codesign",
      arguments: arguments
    )

    return process.runAndWait()
      .mapError { error in
        return .failedToRunCodesignTool(error)
      }
  }

  
  /// Enumerates the user's available codesigning identities.
  /// - Returns: An array of identities, or a failure if the `security` command fails or produces invalid output.
  static func enumerateIdentities() -> Result<[Identity], CodeSignerError> {
    let process = Process.create(
      "/usr/bin/security",
      arguments: ["find-identity", "-pcodesigning", "-v"]
    )

    return process.getOutput()
      .mapError { error in
        return .failedToEnumerateIdentities(error)
      }
      .flatMap { output in
        // Example input: `52635337831A02427192D4FC5EC8528323456F17 "Apple Development: stackotter@stackotter.dev (LK3JHG2345)"`
        let identityParser = Parse {
          PrefixThrough(") ").map(String.init)
          PrefixUpTo(" ").map(String.init)
          " "
          OneOf {
            PrefixUpTo("\n")
            Rest()
          }.map { substring in
            // Remove quotation marks
            substring.dropFirst().dropLast()
          }.map(String.init)
        }.map { _, id, name in
          return Identity(id: id, name: name)
        }

        let identityListParser = Many {
          identityParser
        }

        let identities: [Identity]
        do {
          identities = try identityListParser.parse(output)
        } catch {
          return .failure(.failedToParseIdentityList(error))
        }

        return .success(identities)
      }
  }

  static func getTeamIdentifier(from bundle: URL) -> Result<String, CodeSignerError> {
    Process.create(
      "/usr/bin/openssl",
      arguments: [
        "smime", "-verify",
        "-in", bundle.appendingPathComponent("embedded.mobileprovision").path,
        "-inform", "der"
      ]
    ).getOutput(excludeStdError: true).mapError { error in
      return .failedToVerifyProvisioningProfile(error)
    }.flatMap { plistContent in
      struct Profile: Codable {
        let teamIdentifierArray: [String]

        enum CodingKeys: String, CodingKey {
          case teamIdentifierArray = "TeamIdentifier"
        }
      }

      let profile: Profile
      do {
        profile = try PropertyListDecoder().decode(
          Profile.self,
          from: plistContent.data(using: .utf8) ?? Data()
        )
      } catch {
        return .failure(.failedToDeserializeProvisioningProfile(error))
      }

      guard let identifier = profile.teamIdentifierArray.first else {
        return .failure(.provisioningProfileMissingTeamIdentifier)
      }
      
      return .success(identifier)
    }
  }

  /// Generates the contents of an entitlements file.
  static func generateEntitlementsContent(teamIdentifier: String, bundleIdentifier: String) -> String {
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
