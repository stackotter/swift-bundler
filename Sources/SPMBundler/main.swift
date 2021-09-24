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

// TODO: fix release build metallibs
// TODO: option to show build progress in a window
// TODO: codesigning
// TODO: graceful shutdown
// TODO: xcode support
// TODO: documentation