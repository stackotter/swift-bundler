import Foundation

extension URL {
  /// Gets the path of this URL relative to another URL.
  /// - Parameter base: The base for the relative path.
  /// - Returns: The relative path if both this URL and the base URL are file URLs.
  func relativePath(from base: URL) -> String? {
    // Ensure that both URLs represent files:
    guard self.isFileURL && base.isFileURL else {
      return nil
    }

    // Remove/replace "." and "..", make paths absolute:
    let destComponents = self.standardized.pathComponents
    let baseComponents = base.standardized.pathComponents

    // Find number of common path components:
    var i = 0
    while i < destComponents.count && i < baseComponents.count && destComponents[i] == baseComponents[i] {
      i += 1
    }

    // Build relative path:
    var relComponents = Array(repeating: "..", count: baseComponents.count - i)
    relComponents.append(contentsOf: destComponents[i...])
    return relComponents.joined(separator: "/")
  }
}
