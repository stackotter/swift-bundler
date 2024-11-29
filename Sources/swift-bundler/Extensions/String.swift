import Foundation

extension String {
  /// A quoted version of the string for interpolating into commands.
  /// **This is not secure**, it should only be used in example commands printed to the command-line.
  var quotedIfNecessary: String {
    let specialCharacters: [Character] = [" ", "\\", "\"", "!", "$", "'", "{", "}", ","]
    for character in specialCharacters {
      if self.contains(character) {
        return "'\(self.replacingOccurrences(of: "'", with: "'\\''"))'"
      }
    }
    return self
  }

  /// Reads the contents of a file, returning a result.
  static func read(from file: URL) -> Result<String, any Error> {
    Result {
      try String(contentsOf: file)
    }
  }

  /// Writes the string to a file, returning a result.
  func write(to file: URL) -> Result<Void, any Error> {
    Result {
      try write(to: file, atomically: true, encoding: .utf8)
    }
  }
}
