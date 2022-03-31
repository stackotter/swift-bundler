import Foundation
import ArgumentParser
import Darwin

/// The root command of Swift Bundler.
struct SwiftBundler: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "swift-bundler",
    abstract: "A tool for creating macOS apps from Swift packages.",
    version: "v2.0.0-rc.1",
    shouldDisplay: true,
    subcommands: [
      BundleCommand.self,
      RunCommand.self,
      CreateCommand.self,
      TemplatesCommand.self,
      GenerateXcodeSupportCommand.self
    ])
}

// Kill all running processes on exit
#if os(macOS)
for signal in Signal.allCases {
  trap(signal) { _ in
    for process in processes {
      process.terminate()
    }
    exit(1)
  }
}
#endif

SwiftBundler.main()
