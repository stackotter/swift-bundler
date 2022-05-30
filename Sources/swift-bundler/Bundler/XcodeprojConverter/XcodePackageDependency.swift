import Foundation
import SwiftXcodeProj

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
  }
}
