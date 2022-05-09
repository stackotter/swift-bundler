import Foundation

/// A platform to build for.
enum Platform {
  case macOS(version: String)
  case iOS(version: String)

  /// The platform's version as a string.
  var version: String {
    switch self {
    case .macOS(let version):
      return version
    case .iOS(let version):
      return version
    }
  }
}
