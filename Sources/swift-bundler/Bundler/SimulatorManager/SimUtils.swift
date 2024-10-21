import Foundation

/// Simulator utilities, for working with the values parsed from the `simctl` command-line tool.
enum SimUtils {
  /// Retrieve the OS version decimal as a string for a given simulator runtime string from
  /// `simctl list devices --json`.
  /// ```swift
  /// var osVersion = SimUtils.getOSVersionForRuntime("com.apple.CoreSimulator.SimRuntime.xrOS-2-0")
  /// print(osVersion)
  /// // Prints "2.0"
  /// ```
  /// - Parameter runtime: The given simulator runtime string.
  /// - Returns: The OS version decimal as a string.
  static func getOSVersionForRuntime(_ runtime: String) -> String {
    var osRuntime = runtime

    for os in ["iOS", "xrOS", "tvOS", "watchOS"] {
      if runtime.hasPrefix("com.apple.CoreSimulator.SimRuntime.\(os)") {
        osRuntime.removeFirst("com.apple.CoreSimulator.SimRuntime.\(os)-".count)
        break
      }
    }

    return osRuntime.replacingOccurrences(of: "-", with: ".")
  }
}
