import Foundation
import ArgumentParser

/// An extension to the `ParsableCommand` API with custom error handling.
protocol Command: ParsableCommand {
  /// Implement this instead of `run()` to get custom Swift Bundler error handling.
  func wrappedRun() throws
}

extension Command {
  func run() {
    do {
      try wrappedRun()
    } catch {
      log.error("\(error.localizedDescription)")
      log.debug("Error details: \(error)")
      Foundation.exit(1)
    }
  }
}
