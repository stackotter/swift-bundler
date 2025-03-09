import TOMLKit

extension TOMLDecoder {
  /// Identical to the regular `TOMLDecoder.decode(_:from:)` but with
  /// `Result`-based error handling instead of `throws`.
  func decode<Value: Decodable>(
    _ type: Value.Type,
    from toml: String
  ) -> Result<Value, any Error> {
    Result {
      try decode(type, from: toml)
    }
  }
}
