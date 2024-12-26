import Foundation

#if os(Linux)
  import Glibc
#endif

extension URL {
  /// Gets the path of this URL relative to another URL.
  /// - Parameter base: The base for the relative path.
  /// - Returns: The relative path if both this URL and the base URL are files,
  ///   otherwise the result is undefined. It used to return `nil` in that case,
  ///   but since I know I'll be moving to a proper file path type soon, I won't
  ///   clog up new code with the issues of `URL`.
  func path(relativeTo base: URL) -> String {
    // Remove/replace "." and "..", make paths absolute:
    let destComponents = self.standardized.pathComponents
    let baseComponents = base.standardized.pathComponents

    // Find number of common path components:
    var commonComponentCount = 0
    while commonComponentCount < destComponents.count
      && commonComponentCount < baseComponents.count
      && destComponents[commonComponentCount] == baseComponents[commonComponentCount]
    {
      commonComponentCount += 1
    }

    // Build relative path:
    var relComponents = Array(repeating: "..", count: baseComponents.count - commonComponentCount)
    relComponents.append(contentsOf: destComponents[commonComponentCount...])
    return relComponents.joined(separator: "/")
  }

  /// The current directory.
  static var currentDirectory: URL {
    URL(fileURLWithPath: ".")
  }

  /// ``URL/resolvingSymlinksInPath()`` is broken on Linux, and that's why I
  /// created this function. Tl;dr, if the last path component is a symlink it
  /// doesn't seem to get resolved (at least in the cases I've tried). I don't
  /// know whether this is just some Linux systems or all Linux systems, and I
  /// also don't know whether it's just my Swift version or all Swift versions.
  func actuallyResolvingSymlinksInPath() -> URL {
    #if os(Linux)
      let resolvedPath = String(unsafeUninitializedCapacity: 4097) { buffer in
        realpath(self.path, buffer.baseAddress)
        return strlen(UnsafePointer(buffer.baseAddress!))
      }
      return URL(fileURLWithPath: resolvedPath)
    #else
      return resolvingSymlinksInPath()
    #endif
  }

  /// Gets whether the URL exists on disk or not.
  func exists() -> Bool {
    FileManager.default.fileExists(atPath: path)
  }
}

/// Appends a path component to the end of a URL. Think of it like the actual
/// forward slash in paths (sorry Windows).
func / (_ left: URL, _ right: String) -> URL {
  left.appendingPathComponent(right)
}
