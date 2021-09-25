import Foundation
import ArgumentParser

struct Bundler: ParsableCommand {
  static let configuration = CommandConfiguration(subcommands: [Init.self, GenerateXcodeproj.self, Build.self])
}

Bundler.main()

// TODO: fix metal shader compilation
// TODO: codesigning
// TODO: graceful shutdown
// TODO: documentation
// TODO: make the default main.swift more useful (just a SwiftUI hello world or something)
// TODO: support sandbox
// TODO: check local dependency editing

// Must contain a main.swift otherwise it won't compile as an executable
// The (macOS) target is the actual one