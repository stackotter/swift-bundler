#if os(macOS)
import SwiftXcodeProj

extension XcodeprojConverter {
  /// A type of target in a Swift package.
  enum TargetType {
    case executable
    case library

    /// The name given to this target type in `Package.swift` files.
    var manifestName: String {
      switch self {
        case .executable:
          return "executableTarget"
        case .library:
          return "target"
      }
    }

    /// Creates the suitable target type for the given product type (if any).
    /// - Parameter productType: The product type.
    init?(_ productType: PBXProductType) {
      switch productType {
        case .application:
          self = .executable
        case .staticLibrary, .dynamicLibrary:
          self = .library
        default:
          return nil
      }
    }
  }
}

#endif /* macOS */