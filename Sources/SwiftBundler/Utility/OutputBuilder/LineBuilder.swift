/// A convenient way of building a line of output.
@resultBuilder struct LineBuilder {
  static func buildBlock(_ components: OutputComponent...) -> String {
    components.map(\.body).joined(separator: "")
  }

  static func buildArray(_ components: [OutputComponent]) -> String {
    components.map(\.body).joined(separator: "")
  }

  static func buildOptional(_ component: OutputComponent?) -> String {
    component?.body ?? ""
  }

  static func buildEither(first component: OutputComponent) -> String {
    component.body
  }

  static func buildEither(second component: OutputComponent) -> String {
    component.body
  }
}
