extension Dictionary {
  /// A `Result`-based version of ``Dictionary/mapValues(_:)``. Guaranteed to
  /// short-circuit as soon as a failure occurs. Values are processed in the
  /// order that they appear.
  func tryMapValues<Failure: Error, NewValue>(
    _ transform: (Key, Value) -> Result<NewValue, Failure>
  ) -> Result<[Key: NewValue], Failure> {
    var result: [Key: NewValue] = [:]
    for (key, value) in self {
      switch transform(key, value) {
        case .success(let newValue):
          result[key] = newValue
        case .failure(let error):
          return .failure(error)
      }
    }
    return .success(result)
  }
}
