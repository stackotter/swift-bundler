import Foundation
import X509

/// A very simplified representation of a provisioning profile's plist contents.
struct ProvisioningProfile {
  /// The array of team identifiers.
  let teamIdentifierArray: [String]
  let expirationDate: Date
  let provisionedDevices: [String]
  let platforms: [String]
  let appId: String
  let entitlements: Entitlements
  let certificates: [Certificate]

  enum CodingKeys: String, CodingKey {
    case teamIdentifierArray = "TeamIdentifier"
    case expirationDate = "ExpirationDate"
    case provisionedDevices = "ProvisionedDevices"
    case platforms = "Platform"
    case appId = "AppIDName"
    case entitlements = "Entitlements"
    case certificates = "DeveloperCertificates"
  }

  struct Entitlements: Decodable {
    var applicationIdentifier: String

    enum CodingKeys: String, CodingKey {
      case applicationIdentifier = "application-identifier"
    }
  }

  func suitable(forBundleIdentifier bundleIdentifier: String) -> Bool {
    let bundleIdentifierParts = bundleIdentifier.split(separator: ".")
    let wildcardParts = entitlements.applicationIdentifier.split(separator: ".")
      .dropFirst()

    guard bundleIdentifierParts.count >= wildcardParts.count else {
      return false
    }

    guard
      bundleIdentifierParts.count == wildcardParts.count
        || wildcardParts.last == "*"
    else {
      return false
    }

    return zip(bundleIdentifierParts, wildcardParts)
      .allSatisfy { bundlePart, wildcardPart in
        bundlePart == wildcardPart || wildcardPart == "*"
      }
  }
}

extension ProvisioningProfile: Decodable {
  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      teamIdentifierArray: try container.decode([String].self, forKey: .teamIdentifierArray),
      expirationDate: try container.decode(Date.self, forKey: .expirationDate),
      provisionedDevices: try container.decodeIfPresent([String].self, forKey: .provisionedDevices)
        ?? [],
      platforms: try container.decode([String].self, forKey: .platforms),
      appId: try container.decode(String.self, forKey: .appId),
      entitlements: try container.decode(Entitlements.self, forKey: .entitlements),
      certificates: try container.decode([Data].self, forKey: .certificates).map { certificateDER in
        try Certificate(derEncoded: [UInt8](certificateDER))
      }
    )
  }
}
