import Foundation
import ArgumentParser

struct Command: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "swift-bundler",
    abstract: "A tool for creating macOS apps from Swift packages.",
    version: "v1.4.9",
    shouldDisplay: true,
    subcommands: [
      BuildCommand.self,
      RunCommand.self
    ])
}

Command.main()
