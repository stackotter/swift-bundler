/// An LLVM-compatible target triple.
struct LLVMTargetTriple: CustomStringConvertible {
  /// The target architecture.
  var architecture: BuildArchitecture
  /// The triple's vendor (`"apple"` for Apple devices).
  var vendor: Vendor
  /// The target system (e.g. iOS 15.0).
  var system: System
  /// The target environment/ABI. This is where we specify whether the platform
  /// is a simulator or not.
  var abi: ABI?

  var description: String {
    var triple = "\(architecture.rawValue)-\(vendor.rawValue)-\(system.description)"
    if let abi {
      triple += "-\(abi.rawValue)"
    }
    return triple
  }

  enum Vendor: String {
    case apple
    case unknown
  }

  struct System: CustomStringConvertible {
    var name: String
    var version: String?

    var description: String {
      "\(name)\(version ?? "")"
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

    static func macOS(_ version: String) -> Self {
      Self(name: "macosx", version: version)
    }

    static let linux = Self(name: "linux")

    static let windows = Self(name: "windows")
  }

  enum ABI: String {
    case simulator
    case gnu
    case msvc
  }

  /// Creates the target triple for the specified Apple platform.
  static func apple(
    _ architecture: BuildArchitecture,
    _ system: System,
    _ abi: ABI? = nil
  ) -> Self {
    Self(
      architecture: architecture,
      vendor: .apple,
      system: system,
      abi: abi
    )
  }

  static func apple(
    _ architecture: BuildArchitecture,
    _ platform: ApplePlatform,
    _ platformVersion: String?
  ) -> Self {
    Self(
      architecture: architecture,
      vendor: .apple,
      system: System(
        name: platform.os.tripleName,
        version: platformVersion
      ),
      abi: platform.isSimulator ? .simulator : nil
    )
  }

  static func linux(_ architecture: BuildArchitecture) -> Self {
    Self(
      architecture: architecture,
      vendor: .unknown,
      system: .linux,
      abi: .gnu
    )
  }

  static func windows(_ architecture: BuildArchitecture) -> Self {
    Self(
      architecture: architecture,
      vendor: .unknown,
      system: .windows,
      abi: .msvc
    )
  }
}
