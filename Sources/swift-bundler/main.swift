import Foundation
import ArgumentParser

struct Command: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "swift-bundler",
    abstract: "A tool for creating macOS apps from Swift packages.",
    version: "v1.4.9",
    shouldDisplay: true,
    subcommands: [
      BundleCommand.self,
      RunCommand.self,
      CreateCommand.self,
      PostbuildCommand.self,
      PrebuildCommand.self,
      GenerateXcodeSupportCommand.self
    ])
}

Command.main()
