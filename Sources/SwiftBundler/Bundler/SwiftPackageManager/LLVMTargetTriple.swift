/// An LLVM-compatible target triple.
struct LLVMTargetTriple: CustomStringConvertible {
  /// The target architecture.
  var architecture: BuildArchitecture
  /// The triple's vendor (`"apple"` for Apple devices).
  var vendor: Vendor
  /// The target system (e.g. iOS 15.0).
  var system: System
  /// The target environment. This is where we specify whether the platform
  /// is a simulator or not.
  var environment: Environment?

  var description: String {
    var triple = "\(architecture.rawValue)-\(vendor.rawValue)-\(system.description)"
    if let environment = environment {
      triple += "-\(environment.rawValue)"
    }
    return triple
  }

  enum Vendor: String {
    case apple
  }

  struct System: CustomStringConvertible {
    var name: String
    var version: String

    var description: String {
      "\(name)\(version)"
    }

    static func iOS(_ version: String) -> Self {
      Self(name: "ios", version: version)
    }

    static func visionOS(_ version: String) -> Self {
      Self(name: "xros", version: version)
    }

    static func tvOS(_ version: String) -> Self {
      Self(name: "tvos", version: version)
    }
  }

  enum Environment: String {
    case simulator
  }

  /// Creates the target triple for the specified Apple platform.
  static func apple(
    _ architecture: BuildArchitecture,
    _ system: System,
    _ environment: Environment? = nil
  ) -> Self {
    Self(
      architecture: architecture,
      vendor: .apple,
      system: system,
      environment: environment
    )
  }
}
