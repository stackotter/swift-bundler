import Foundation
import ArgumentParser

struct Bundler: ParsableCommand {
  static let configuration = CommandConfiguration(subcommands: [Init.self, GenerateXcodeproj.self, Build.self, Run.self])
}

Bundler.main()

// TODO: graceful shutdown
// TODO: support sandbox
// TODO: add proper help messages to subcommands, options and flags