/// A component that displays a series of ordered key value pairs.
struct OutputDictionary: OutputComponent {
  /// An entry in an ordered dictionary.
  struct Entry: OutputComponent {
    /// The key.
    var key: String
    /// The value.
    var value: String
    
    var body: String {
      "* " + key.bold + ": " + value
    }
    
    /// Creates a dictionary entry.
    /// - Parameters:
    ///   - key: The key.
    ///   - value: The value.
    init(_ key: String, _ value: OutputComponent) {
      self.key = key
      self.value = value.body
    }
    
    /// Creates a dictionary entry.
    /// - Parameters:
    ///   - key: The key
    ///   - value: The component to render as the value.
    init(_ key: String, @OutputBuilder _ value: () -> String) {
      self.key = key
      self.value = value()
    }
  }
  
  /// The contents of the dictionary.
  var contents: [Entry]

  var body: String {
    contents.map(\.body).joined(separator: "\n")
  }
  
  /// Creates a dictionary component.
  /// - Parameter contents: The dictionary's entries.
  init(@OutputDictionaryBuilder _ contents: () -> [Entry]) {
    self.contents = contents()
  }
  
  /// Creates a dictionary component.
  /// - Parameter contents: The dictionary's entries.
  init(_ contents: [Entry]) {
    self.contents = contents
  }
}

