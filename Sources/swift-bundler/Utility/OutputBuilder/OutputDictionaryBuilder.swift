/// A convenient way to create the entries for an ``OutputDictionary``.
@resultBuilder struct OutputDictionaryBuilder {
  static func buildBlock(_ components: OutputDictionary.Entry...) -> [OutputDictionary.Entry] {
    components
  }
}
