/// A convenient way to create the entries for an ``OutputDictionary``.
@resultBuilder struct OutputDictionaryBuilder {
  static func buildBlock(_ components: OutputDictionary.Entry...) -> [OutputDictionary.Entry] {
    components
  }

  static func buildBlock(_ components: [OutputDictionary.Entry]...) -> [OutputDictionary.Entry] {
    components.flatMap { $0 }
  }

  static func buildArray(_ components: [[OutputDictionary.Entry]]) -> [OutputDictionary.Entry] {
    components.flatMap { $0 }
  }

  static func buildOptional(_ component: [OutputDictionary.Entry]?) -> [OutputDictionary.Entry] {
    component ?? []
  }

  static func buildEither(first component: [OutputDictionary.Entry]) -> [OutputDictionary.Entry] {
    component
  }

  static func buildEither(second component: [OutputDictionary.Entry]) -> [OutputDictionary.Entry] {
    component
  }
}
