import Foundation
import ArgumentParser

enum BuildConfiguration: String {
  case debug
  case release
}

struct Bundler: ParsableCommand {
  static let configuration = CommandConfiguration(subcommands: [Init.self, GenerateXcodeproj.self, Build.self])
}

Bundler.main()

// TODO: fix metal shader compilation
// TODO: option to show build progress in a window
// TODO: codesigning
// TODO: graceful shutdown
// TODO: documentation
// TODO: make the default main.swift more useful (just a SwiftUI hello world or something)
// TODO: support sandbox
// TODO: get rid of 'Dummy' folder in xcode

// Must contain a main.swift otherwise it won't compile as an executable
// The (macOS) target is the actual one