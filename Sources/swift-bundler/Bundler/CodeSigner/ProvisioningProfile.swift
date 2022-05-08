import Foundation

/// A very simplified representation of a provisioning profile's plist contents.
struct ProvisioningProfile: Codable {
  /// The array of team identifiers.
  let teamIdentifierArray: [String]

  enum CodingKeys: String, CodingKey {
    case teamIdentifierArray = "TeamIdentifier"
  }
}
