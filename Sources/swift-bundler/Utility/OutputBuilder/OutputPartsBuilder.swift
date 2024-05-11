/// A convenient way of building complex command line output. The output is an array of strings
/// instead of combining all of the parts into a single string like ``OutputBuilder`` would.
/// Separate from OutputBuilder because result builder inference got broken in Swift 5.8.
@resultBuilder struct OutputPartsBuilder {
  static func buildBlock(_ components: OutputComponent...) -> [String] {
    return components.map(\.body)
  }

  static func buildArray(_ components: [OutputComponent]) -> [String] {
    return components.map(\.body)
  }

  static func buildOptional(_ component: OutputComponent?) -> [String] {
    return [component?.body ?? ""]
  }

  static func buildEither(first component: OutputComponent) -> [String] {
    return [component.body]
  }

  static func buildEither(second component: OutputComponent) -> [String] {
    return [component.body]
  }
}
