extension String {
  /// A quoted version of the string for interpolating into commands. This is not secure, it should only be used in example commands printed to the command-line.
  var quotedIfNecessary: String {
    let specialCharacters: [Character] = [" ", "\\", "\"", "!", "$", "'", "{", "}", ","]
    for character in specialCharacters {
      if self.contains(character) {
        return "'\(self.replacingOccurrences(of: "'", with: "'\\''"))'"
      }
    }
    return self
  }
}
