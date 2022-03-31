/// A component that renders its children one after another with newlines separating them.
struct Sections: OutputComponent {
  /// The sections.
  var content: [String]
  
  var body: String {
    content.joined(separator: "\n")
  }
  
  /// Creates a group of sections separated by newlines.
  /// - Parameter content: The child components.
  init(@OutputBuilder _ content: () -> [String]) {
    self.content = content()
  }
}
