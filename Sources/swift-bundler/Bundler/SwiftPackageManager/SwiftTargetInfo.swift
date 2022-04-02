import Foundation

/// An extremely simplified version of the output of `swift -print-target-info`.
struct SwiftTargetInfo: Codable {
  /// Info about a target platform.
  struct Target: Codable {
    /// The platform's unversioned triple.
    var unversionedTriple: String
  }

  /// Info about the target platform.
  var target: Target
}
