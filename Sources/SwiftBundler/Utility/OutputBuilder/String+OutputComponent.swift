extension String: OutputComponent {
  var body: String {
    // StringOutput is used to avoid an infinite loop caused by result builders
    StringOutput(self)
  }
}
