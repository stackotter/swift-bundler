/// A convenient way of building a line of output. The output is an array of string parts. If you
/// want the parts to be combined into a single string, use `LineBuilder`.
@resultBuilder struct LinePartsBuilder {
  static func buildBlock(_ components: OutputComponent...) -> [String] {
    components.map(\.body)
  }

  static func buildArray(_ components: [OutputComponent]) -> [String] {
    components.map(\.body)
  }

  static func buildOptional(_ component: OutputComponent?) -> [String] {
    [component?.body ?? ""]
  }

  static func buildEither(first component: OutputComponent) -> [String] {
    [component.body]
  }

  static func buildEither(second component: OutputComponent) -> [String] {
    [component.body]
  }
}
