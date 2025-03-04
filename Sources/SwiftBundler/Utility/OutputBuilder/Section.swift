/// A section of command-line output. Can have a title.
struct Section: OutputComponent {
  /// The section's title.
  var title: String?
  /// Whether to include a trailing newline or not.
  var trailingNewline: Bool
  /// The section's content.
  var content: String

  var body: String {
    if let title = title {
      title.bold.underline + "\n"
    }
    content + (trailingNewline ? "\n" : "")
  }

  /// Creates a section of command-line output.
  /// - Parameters:
  ///   - title: The title for the section.
  ///   - trailingNewline: Whether to include a trailing newline or not.
  ///   - content: The section's content.
  init(
    _ title: String? = nil,
    trailingNewline: Bool = true,
    @OutputBuilder _ content: () -> String
  ) {
    self.title = title
    self.trailingNewline = trailingNewline
    self.content = content()
  }
}
