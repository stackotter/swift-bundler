import Foundation

extension JSONEncoder {
  /// Attempts to encode the given value as JSON, returning a result.
  func encode<T: Encodable>(_ value: T) -> Result<Data, any Error> {
    Result {
      try encode(value)
    }
  }
}
