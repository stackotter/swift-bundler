import Foundation
import XcodeProj

extension XcodeprojConverter {
  /// An Xcode target's dependency on a package's product.
  struct XcodePackageDependency {
    /// The product that is depended on.
    var product: String
    /// The package's name.
    var package: String
    /// The package's URL.
    var url: URL
    /// The required version of the package.
    var version: XCRemoteSwiftPackageReference.VersionRequirement

    /// Swift source code that conveys the dependency's version requirement in a Swift Package
    /// Manager manifest file dependencies section.
    var requirementParameterSource: String {
      switch version {
        case .branch(let branch):
          return "branch: \"\(branch)\""
        case .exact(let version):
          return "exact: \"\(version)\""
        case .range(let minimum, let maximum):
          return "\"\(minimum)\"..<\"\(maximum)\""
        case .revision(let revision):
          return "revision: \"\(revision)\""
        case .upToNextMajorVersion(let version):
          return ".upToNextMajor(from: \"\(version)\")"
        case .upToNextMinorVersion(let version):
          return ".upToNextMinor(from: \"\(version)\")"
      }
    }
  }
}
