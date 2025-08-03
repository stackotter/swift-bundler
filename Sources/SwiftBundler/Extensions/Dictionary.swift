extension Dictionary {
  /// A typed throws version of the standard `mapValues` method.
  func mapValues<E: Error, NewValue>(
    _ transform: (Key, Value) throws(E) -> NewValue
  ) throws(E) -> [Key: NewValue] {
    var result: [Key: NewValue] = [:]
    for (key, value) in self {
      result[key] = try transform(key, value)
    }
    return result
  }
}
