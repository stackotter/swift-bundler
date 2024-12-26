import Foundation

/// Context provided to builders.
public protocol BuilderContext {
  /// The directory to output built products to. Unique to the library/app
  /// getting built so can be used for various other temporary files too.
  var buildDirectory: URL { get }

  /// Runs the given command (either a path or a tool name) with the given
  /// arguments.
  func run(_ command: String, _ arguments: [String]) throws
}
