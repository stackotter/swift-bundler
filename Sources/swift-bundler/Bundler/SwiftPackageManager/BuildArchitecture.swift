import Foundation
import ArgumentParser

/// An architecture to build for.
enum BuildArchitecture: String, CaseIterable, ExpressibleByArgument {
  case x86_64 // swiftlint:disable:this identifier_name
  case arm64

#if arch(x86_64)
  static let current: BuildArchitecture = .x86_64
#elseif arch(arm64)
  static let current: BuildArchitecture = .arm64
#endif

  var defaultValueDescription: String {
    rawValue
  }
}
