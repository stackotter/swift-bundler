import Foundation

extension PropertyListEncoder {
  func encode<Value: Encodable>(_ value: Value) -> Result<Data, Error> {
    Result {
      try encode(value)
    }
  }
}
