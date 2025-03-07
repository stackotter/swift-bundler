import ArgumentParser
import Foundation

/// An architecture to build for.
enum BuildArchitecture: String, CaseIterable, ExpressibleByArgument {
  case x86_64  // swiftlint:disable:this identifier_name
  case arm64

  #if arch(x86_64)
    static let current: BuildArchitecture = .x86_64
  #elseif arch(arm64)
    static let current: BuildArchitecture = .arm64
  #endif

  var defaultValueDescription: String {
    rawValue
  }

  /// Gets the argument's name in the form required for use in build arguments. Some platforms use
  /// different names for architectures.
  func argument(for platform: Platform) -> String {
    switch (platform, self) {
      case (.linux, .arm64), (.windows, .arm64):
        return "aarch64"
      default:
        return rawValue
    }
  }
}
