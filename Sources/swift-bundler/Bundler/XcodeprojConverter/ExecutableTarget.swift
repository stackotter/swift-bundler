import Foundation

extension XcodeprojConverter {
  /// An executable target in an Xcode project.
  struct ExecutableTarget: XcodeTarget {
    var name: String
    var identifier: String?
    var version: String?
    var sources: [XcodeFile]
    var resources: [XcodeFile]
    var dependencies: [String]
    var packageDependencies: [XcodePackageDependency]

    var targetType: TargetType {
      return .executable
    }

    /// The target's minimum macOS version.
    var macOSDeploymentVersion: String?
    /// The target's minimum iOS version.
    var iOSDeploymentVersion: String?
    /// The target's `Info.plist` file.
    var infoPlist: URL?
  }
}
