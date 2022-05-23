import Foundation

extension XcodeprojConverter {
  /// A library target in an Xcode project.
  struct LibraryTarget: XcodeTarget {
    var name: String
    var identifier: String?
    var version: String?
    var sources: [XcodeFile]
    var resources: [XcodeFile]
    var dependencies: [String]

    var targetType: TargetType {
      return .library
    }
  }
}
