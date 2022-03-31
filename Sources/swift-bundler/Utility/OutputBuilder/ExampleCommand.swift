/// A component that displays an example command.
struct ExampleCommand: OutputComponent {
  /// The command to display.
  var command: String
  
  var body: String {
    "$ " + command.cyan
  }
  
  /// Creates a component that displays a command in an obvious way.
  /// - Parameter command: The command to display.
  init(_ command: String) {
    self.command = command
  }
}
