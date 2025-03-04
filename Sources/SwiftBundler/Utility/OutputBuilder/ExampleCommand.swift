/// A component that displays an example command.
struct ExampleCommand: OutputComponent {
  /// The command to display.
  var command: String
  /// Includes a prompt before the command if `true`.
  var includePrompt: Bool

  var body: String {
    (includePrompt ? "$ " : "") + command.cyan
  }

  /// Creates a component that displays a command in an obvious way.
  /// - Parameters:
  ///   - command: The command to display.
  ///   - includePrompt: Include a prompt before the command.
  init(_ command: String, withPrompt includePrompt: Bool = true) {
    self.command = command
    self.includePrompt = includePrompt
  }
}
