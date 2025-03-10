import ArgumentParser
import Foundation

/// The subcommand for updating the default templates repository.
struct TemplatesUpdateCommand: Command {
  static var configuration = CommandConfiguration(
    commandName: "update",
    abstract: "Update the default templates to the latest version."
  )

  func wrappedRun() async throws {
    let elapsed = try await Stopwatch.time {
      try await Templater.updateTemplates().unwrap()
    }

    log.info("Done in \(elapsed.secondsString).")
  }
}
