import Foundation

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
  /// - Returns: The time taken to execute the provided action.
  static func time<E: Error>(_ action: () throws(E) -> Void) throws(E) -> Measurement {
    let start = ProcessInfo.processInfo.systemUptime
    try action()
    let elapsed = ProcessInfo.processInfo.systemUptime - start
    return Measurement(seconds: elapsed)
  }

  /// Times how long an action takes to run.
  /// - Returns: The time taken along with the result of the provided action.
  static func time<R, E: Error>(_ action: () throws(E) -> R) throws(E) -> (Measurement, R) {
    let start = ProcessInfo.processInfo.systemUptime
    let result = try action()
    let elapsed = ProcessInfo.processInfo.systemUptime - start
    return (Measurement(seconds: elapsed), result)
  }

  /// Times how long an action takes to run.
  /// - Returns: The time taken to execute the provided action.
  static func time<E: Error>(_ action: () async throws(E) -> Void) async throws(E) -> Measurement {
    let start = ProcessInfo.processInfo.systemUptime
    try await action()
    let elapsed = ProcessInfo.processInfo.systemUptime - start
    return Measurement(seconds: elapsed)
  }

  /// Times how long an action takes to run.
  /// - Returns: The time taken along with the result of the provided action.
  static func time<R, E: Error>(
    _ action: () async throws(E) -> R
  ) async throws(E) -> (Measurement, R) {
    let start = ProcessInfo.processInfo.systemUptime
    let result = try await action()
    let elapsed = ProcessInfo.processInfo.systemUptime - start
    return (Measurement(seconds: elapsed), result)
  }
}
