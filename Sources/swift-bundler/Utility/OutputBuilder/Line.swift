/// A component that combines multiple components into one line.
struct Line: OutputComponent {
	/// The child components.
	var content: String

	var body: String {
		content
	}

	/// Creates a component that combines multiple components into one line.
	/// - Parameter content: The child components.
	init(@LineBuilder _ content: () -> String) {
		self.content = content()
	}
}
