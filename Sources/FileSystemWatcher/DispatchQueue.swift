import Foundation

// TODO: Replace usage of DispatchQueue with structured concurrency.
extension DispatchQueue {
  static func runOnMainThread(_ action: @MainActor () throws -> Void) rethrows {
    if Thread.isMainThread {
      try MainActor.assumeIsolated {
        try action()
      }
    } else {
      try DispatchQueue.main.sync {
        try action()
      }
    }
  }
}
