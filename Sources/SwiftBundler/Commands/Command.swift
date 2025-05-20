import ArgumentParser
import Foundation

/// An extension to the `ParsableCommand` API with custom error handling.
protocol Command: AsyncParsableCommand {
  /// Implement this instead of `validate()` to get custom Swift Bundler error handling.
  func wrappedValidate() throws

  /// Implement this instead of `run()` to get custom Swift Bundler error handling.
  func wrappedRun() async throws
}

extension Command {
  func wrappedValidate() {}
}

extension Command {
  func run() async {
    do {
      try await wrappedRun()
    } catch {
      log.error("\(error.localizedDescription)")
      log.debug("Error details: \(error)")
      if log.logLevel > .debug {
        print("")
        log.info("Use --verbose to get more error details")
      }
      Foundation.exit(1)
    }
  }

  func validate() {
    do {
      try wrappedValidate()
    } catch {
      if let error = error as? ValidationError {
        log.error("\(error)")
      } else {
        log.error("\(error.localizedDescription)")
      }
      Foundation.exit(1)
    }
  }
}
