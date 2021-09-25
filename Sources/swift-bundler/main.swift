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
// TODO: support sandbox
// TODO: check local dependency editing
// TODO: rename to swift-bundler
// TODO: add an option to generate-xcodeproj to hide dependencies group
// TODO: add proper help messages to subcommands, options and flags

// Must contain a main.swift otherwise it won't compile as an executable
// The (macOS) target is the actual one
// macos platform version in Package.swift must be at least 11.0