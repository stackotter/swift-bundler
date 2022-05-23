import Foundation

/// A target in an Xcode project.
protocol XcodeTarget {
  /// The target's name.
  var name: String { get set }
  /// The target's identifier.
  var identifier: String? { get set }
  /// The target's version.
  var version: String? { get set }
  /// The target's source code files.
  var sources: [XcodeprojConverter.XcodeFile] { get set }
  /// The target's resource files.
  var resources: [XcodeprojConverter.XcodeFile] { get set }
  /// The names of targets that the target depends on.
  var dependencies: [String] { get set }
  /// The type of target.
  var targetType: XcodeprojConverter.TargetType { get }
}

extension XcodeTarget {
  /// All of the target's files (both source code and resource files).
  var files: [XcodeprojConverter.XcodeFile] {
    return sources + resources
  }
}
