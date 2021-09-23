import Foundation

extension FileManager {
  enum ItemType {
    case file
    case directory
  }

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

  func createDirectory(at url: URL) throws {
    try createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
  }
}