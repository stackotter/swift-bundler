/// A section of command-line output. Can have a title.
struct Section: OutputComponent {
  /// The section's title.
  var title: String?
  /// The section's content.
  var content: String

  var body: String {
    if let title = title {
      title.bold.underline + "\n"
    }
    content + "\n"
  }

  /// Creates a section of command-line output.
  /// - Parameters:
  ///   - title: The title for the section.
  ///   - content: The section's content.
  init(_ title: String? = nil, @OutputBuilder _ content: () -> String) {
    self.title = title
    self.content = content()
  }
}
