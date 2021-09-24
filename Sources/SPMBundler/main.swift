import Foundation
import ArgumentParser

struct Bundler: ParsableCommand {
  static let configuration = CommandConfiguration(subcommands: [Init.self, GenerateXcodeproj.self, Build.self])
}

// runProgressJob({ setMessage, setProgress in 
//   setMessage("[4/5] Linking DeltaClientSPM")
//   setProgress(1)
//   sleep(5)
// },
// title: "Build",
// maxProgress: 2)

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