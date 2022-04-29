import Foundation

/// An error thrown by the Swift Bundler CLI.
enum CLIError: LocalizedError {
  case invalidPlatform(String)
  case invalidArchitecture(String)
  case invalidBuildConfiguration(String)
}
