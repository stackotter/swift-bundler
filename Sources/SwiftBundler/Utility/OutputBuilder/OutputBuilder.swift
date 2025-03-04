/// A convenient way of building complex command line output.
@resultBuilder struct OutputBuilder {
  static func buildBlock(_ components: OutputComponent...) -> String {
    return components.map(\.body).joined(separator: "\n")
  }

  static func buildArray(_ components: [OutputComponent]) -> String {
    return components.map(\.body).joined(separator: "\n")
  }

  static func buildOptional(_ component: OutputComponent?) -> String {
    return component?.body ?? ""
  }

  static func buildEither(first component: OutputComponent) -> String {
    return component.body
  }

  static func buildEither(second component: OutputComponent) -> String {
    return component.body
  }
}
