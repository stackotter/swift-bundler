/// A component that displays an array of strings as an inline list.
struct InlineList: OutputComponent {
  /// The elements to display as an inline list.
  var elements: [String]

  var body: String {
    "[" + elements.joined(separator: ", ") + "]"
  }

  /// Creates a component that displays an array of strings as an inline list.
  /// - Parameter elements: Elements of the list to display.
  init(_ elements: [String]) {
    self.elements = elements
  }
}
