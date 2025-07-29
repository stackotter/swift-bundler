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

  /// Reads the contents of a file, returning a result.
  static func read(from file: URL) throws -> String {
    try String(contentsOf: file)
  }

  /// Writes the string to a file, returning a result.
  func write(to file: URL) -> Result<Void, any Error> {
    Result {
      try write(to: file, atomically: true, encoding: .utf8)
    }
  }

  /// Writes the string to a file, returning a result.
  func write(to file: URL) throws {
    try write(to: file, atomically: true, encoding: .utf8)
  }

  /// Gets the string with 'a' or 'an' prepended depending on whether the
  /// word starts with a vowel or not. May not be perfect (English probably
  /// has edge cases).
  var withIndefiniteArticle: String {
    guard let first = first else {
      return self
    }

    if ["a", "e", "i", "o", "u"].contains(first) {
      return "an \(self)"
    } else {
      return "a \(self)"
    }
  }
}

extension String.Index {
  func offset(in string: String) -> Int {
    string.distance(from: string.startIndex, to: self)
  }
}
