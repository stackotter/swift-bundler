import Foundation

/// A proper semantic version, as parsed from the OS version
/// from the `simctl` command-line tool, with a `major`, `minor`,
/// and `patch` integer, and easily sortable.
/// ```swift
/// var versions = [
///   OSVersion("1.0"), 
///   OSVersion("18"), 
///   OSVersion("2.0.0")
/// ]
///
/// versions.sort { $0 > $1 }
///
/// print(versions.map { v in
///   "\(v.major).\(v.minor).\(v.patch)"
/// })
/// // Prints ["18.0.0", "2.0.0", "1.0.0"]
/// ```
struct OSVersion: Comparable, Codable {
  let major: Int
  let minor: Int
  let patch: Int

  /// Create a semantic version from a string.
  init(_ version: String) {
    let components = version.split(separator: ".").map { Int($0) ?? 0 }
    self.major = components.count > 0 ? components[0] : 0
    self.minor = components.count > 1 ? components[1] : 0
    self.patch = components.count > 2 ? components[2] : 0
  }

  /// Conforms to the `Comparable` protocol for easy sorting.
  static func < (lhs: OSVersion, rhs: OSVersion) -> Bool {
    if lhs.major != rhs.major {
      return lhs.major < rhs.major
    }
    if lhs.minor != rhs.minor {
      return lhs.minor < rhs.minor
    }
    return lhs.patch < rhs.patch
  }

  /// Conforms to the `Decodable` protocol for decoding from strings.
  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let versionString = try container.decode(String.self)
    self.init(versionString)
  }

  /// Conforms to the `Encodable` protocol for encoding to strings.
  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    let versionString = "\(major).\(minor).\(patch)"
    try container.encode(versionString)
  }
}
