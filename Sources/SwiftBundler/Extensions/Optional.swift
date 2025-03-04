extension Optional {
  /// If some, returns a success, otherwise returns the given failure. Just a
  /// handy helper method for attaching errors to optional values.
  func okOr<Failure>(_ error: Failure) -> Result<Wrapped, Failure> {
    guard let value = self else {
      return .failure(error)
    }

    return .success(value)
  }
}
