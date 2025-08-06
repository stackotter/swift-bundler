import ArgumentParser
import Foundation
import ErrorKit

/// An extension to the `AsyncParsableCommand` API with custom error handling.
protocol ErrorHandledCommand: AsyncParsableCommand {
  associatedtype ErrorMessage: Throwable

  var verbose: Bool { get }

  /// Implement this instead of `validate()` to get custom Swift Bundler error handling.
  func wrappedValidate() throws(RichError<ErrorMessage>)

  /// Implement this instead of `run()` to get custom Swift Bundler error handling.
  func wrappedRun() async throws(RichError<ErrorMessage>)
}

extension ErrorHandledCommand {
  func wrappedValidate() {}
}

extension ErrorHandledCommand {
  func validate() {
    // A bit of a hack to set the verbosity level whenever the verbose option is set on the root command
    if verbose {
      log.logLevel = .debug
    }

    do {
      try wrappedValidate()
    } catch {
      log.error("\(chainDescription(for: error, verbose: verbose))")
      Foundation.exit(1)
    }
  }

  func run() async {
    do {
      try await wrappedRun()
    } catch {
      log.error("\(chainDescription(for: error, verbose: verbose))")
      Foundation.exit(1)
    }
  }
}
