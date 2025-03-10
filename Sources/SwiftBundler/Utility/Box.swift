/// A wrapper that can be used when a value type needs approximate reference
/// semantics.
class Box<T> {
  var wrapped: T

  init(_ inner: T) {
    wrapped = inner
  }
}
