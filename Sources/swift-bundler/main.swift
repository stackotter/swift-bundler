import Foundation
import ArgumentParser
import Darwin

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
      GenerateXcodeSupportCommand.self,
      TemplatesCommand.self
    ])
}

// Kill all running processes on exit
#if os(macOS)
trap(.interrupt) { _ in
  for process in processes {
    process.terminate()
  }
  exit(1)
}
#endif

Command.main()
log.info("Done")
