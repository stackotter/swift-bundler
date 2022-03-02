import Foundation

extension URL {
  var escapedPath: String {
    return self.path
      .replacingOccurrences(of: " ", with: "\\ ")
      .replacingOccurrences(of: "\"", with: "\\\"")
  }
}
