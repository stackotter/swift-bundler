import Foundation
import ArgumentParser

struct Bundler: ParsableCommand {
  static let configuration = CommandConfiguration(subcommands: [Init.self, GenerateXcodeSupport.self, Build.self, Run.self, Prebuild.self, Bundle.self, RemoveFileHeaders.self])
}