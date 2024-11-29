import Foundation

extension JSONDecoder {
  /// Attempts to decode the given JSON data as an instance of the given type,
  /// returning a result.
  func decode<T: Decodable>(
    _ type: T.Type,
    from data: Data
  ) -> Result<T, any Error> {
    Result {
      try decode(type, from: data)
    }
  }
}
