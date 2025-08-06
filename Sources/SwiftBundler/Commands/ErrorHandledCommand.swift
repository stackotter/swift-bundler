import ArgumentParser
import Foundation
import ErrorKit

/// An extension to the `AsyncParsableCommand` API with custom error handling.
protocol ErrorHandledCommand: AsyncParsableCommand {
  associatedtype ErrorMessage: Throwable

  /// Implement this instead of `validate()` to get custom Swift Bundler error handling.
  func wrappedValidate() throws(RichError<ErrorMessage>)

  /// Implement this instead of `run()` to get custom Swift Bundler error handling.
  func wrappedRun() async throws(RichError<ErrorMessage>)
}

extension ErrorHandledCommand {
  func wrappedValidate() {}
}

extension ErrorHandledCommand {
  func run() async {
    do {
      try await wrappedRun()
    } catch {
      log.error("\(chainDescription(for: error))")
      Foundation.exit(1)
    }
  }

  func validate() {
    do {
      try wrappedValidate()
    } catch {
      log.error("\(chainDescription(for: error))")
      Foundation.exit(1)
    }
  }
}
