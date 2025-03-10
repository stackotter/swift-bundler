/// A component that combines multiple components.
struct Output: OutputComponent {
  /// The child components.
  var content: [String]

  var body: String {
    content.joined(separator: "\n")
  }

  /// Combines multiple components.
  /// - Parameter content: The child components.
  init(@OutputPartsBuilder _ content: () -> [String]) {
    self.content = content()
  }
}
