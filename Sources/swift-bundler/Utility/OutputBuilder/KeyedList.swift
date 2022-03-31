/// A component that displays a series of ordered key value pairs.
struct KeyedList: OutputComponent {
  /// An entry in a keyed list.
  struct Entry: OutputComponent {
    /// The key.
    var key: String
    /// The value.
    var value: String

    var body: String {
      "* " + key.bold + ": " + value
    }

    /// Creates a keyed list entry.
    /// - Parameters:
    ///   - key: The key.
    ///   - value: The value.
    init(_ key: String, _ value: OutputComponent) {
      self.key = key
      self.value = value.body
    }

    /// Creates a keyed list entry.
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

  /// Creates a keyed list component.
  /// - Parameter contents: The list's entries.
  init(@KeyedListBuilder _ contents: () -> [Entry]) {
    self.contents = contents()
  }

  /// Creates a keyed list component.
  /// - Parameter contents: The list's entries.
  init(_ contents: [Entry]) {
    self.contents = contents
  }
}
