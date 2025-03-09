/// A simple output component that displays the string that it is given. Used to avoid an infinite loop that would otherwise occur in `String.body`.
struct StringOutput: OutputComponent {
  var body: String

  /// Creates an output component that displays a string.
  /// - Parameter content: The string to display.
  init(_ content: String) {
    body = content
  }
}
