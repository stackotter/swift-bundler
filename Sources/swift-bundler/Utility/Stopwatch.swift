import Foundation
import CoreFoundation

/// A utility for timing arbitrary actions.
enum Stopwatch {
  /// A stopwatch measurement.
  struct Measurement {
    /// The time elapsed in seconds.
    var seconds: Double

    /// The time elapsed in milliseconds.
    var milliseconds: Double {
      seconds * 1000
    }

    /// A string of the form `{seconds}s` where `{seconds}` is ``seconds`` to 2 decimal places.
    var secondsString: String {
      String(format: "%.02fs", seconds)
    }

    /// A string of the form `{milliseconds}s` where `{milliseconds}` is ``milliseconds`` to 2 decimal places.
    var millisecondsString: String {
      String(format: "%.02fms", milliseconds)
    }
  }

  /// Times how long an action takes to run.
  static func time(_ action: () throws -> Void) rethrows -> Measurement {
    let start = CFAbsoluteTimeGetCurrent()
    try action()
    let elapsed = CFAbsoluteTimeGetCurrent() - start
    return Measurement(seconds: elapsed)
  }

  /// Times how long an action takes to run.
  static func time(_ action: () async throws -> Void) async rethrows -> Measurement {
    let start = CFAbsoluteTimeGetCurrent()
    try await action()
    let elapsed = CFAbsoluteTimeGetCurrent() - start
    return Measurement(seconds: elapsed)
  }
}
