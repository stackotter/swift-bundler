import Foundation

extension ProcessInfo {
  /// Configuration parsed from the environment and used by Swift Bundler.
  var bundlerEnvironment: BundlerEnvironment {
    BundlerEnvironment.parse(environment)
  }

  /// Configuration parsed from the environment and used by Swift Bundler.
  struct BundlerEnvironment {
    /// Defaults to `true` if not set in the environment.
    var useXCBeautify: Bool

    static func parse(_ environment: [String: String]) -> Self {
      Self(
        useXCBeautify: environment["SWIFT_BUNDLER_USE_XCBEAUTIFY"] != "0"
      )
    }
  }
}
