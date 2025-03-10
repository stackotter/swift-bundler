#if SUPPORT_XCODEPROJ
  import XcodeProj

  extension PBXProductType {
    /// Whether the product is executable or not.
    var isExecutable: Bool {
      return self == .application
    }

    /// Whether the product is a library or not.
    var isLibrary: Bool {
      return self == .staticLibrary || self == .dynamicLibrary
    }
  }
#endif
