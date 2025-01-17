import Foundation

/// A very simplified representation of a provisioning profile's plist contents.
struct ProvisioningProfile: Decodable {
  /// The array of team identifiers.
  let teamIdentifierArray: [String]
  let expirationDate: Date
  let provisionedDevices: [String]
  let platforms: [String]
  let appId: String
  let entitlements: Entitlements

  enum CodingKeys: String, CodingKey {
    case teamIdentifierArray = "TeamIdentifier"
    case expirationDate = "ExpirationDate"
    case provisionedDevices = "ProvisionedDevices"
    case platforms = "Platform"
    case appId = "AppIDName"
    case entitlements = "Entitlements"
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
