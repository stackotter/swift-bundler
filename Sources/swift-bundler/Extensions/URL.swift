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
}
