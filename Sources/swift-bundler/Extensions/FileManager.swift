import Foundation

extension FileManager {
  /// The type of an item on the file system.
  enum ItemType {
    case file
    case directory
  }

  /// Gets whether an item of a specific type exists at the given `URL` or not.
  /// - Parameters:
  ///   - url: The URL of the item to check for.
  ///   - type: The type that the item must be.
  /// - Returns: `true` if an item of the specified type exists at the specified location.
  func itemExists(at url: URL, withType type: ItemType) -> Bool {
    var isDirectory: ObjCBool = false
    if fileExists(atPath: url.path, isDirectory: &isDirectory) {
      if isDirectory.boolValue && type == .directory {
        return true
      } else if !isDirectory.boolValue && type == .file {
        return true
      }
    }
    return false
  }
  
  /// Creates a directory.
  /// - Parameter url: The directory to create.
  /// - Throws: An error if directory creation fails.
  func createDirectory(at url: URL) throws {
    try createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
  }
}
