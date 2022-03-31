/// A component that displays a list of elements, each on a new line.
struct List: OutputComponent {
  /// The list's elements.
  var elements: [String]
  
  var body: String {
    for element in elements {
      "* " + element
    }
  }
  
  /// Creates a component to display a list of elements.
  /// - Parameter content: The elements to display.
  init(@OutputBuilder _ content: () -> [String]) {
    self.elements = content()
  }
  
  /// Creates a component to display a list of elements.
  /// - Parameter elements: The elements to display.
  init(_ elements: [String]) {
    self.elements = elements
  }
}
