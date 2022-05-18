import Foundation

/// An error that can occur while encoding or decoding a ``PlistValue``.
enum PlistError: LocalizedError {
  case invalidValue(String, type: String, codingPath: [CodingKey])
  case failedToInferType(codingPath: [CodingKey])
  case invalidExplicitlyTypedValue(type: String, codingPath: [CodingKey])

  var errorDescription: String? {
    switch self {
      case .invalidValue(let value, let type, let codingPath):
        let path = codingPath.map(\.stringValue).joined(separator: ".")
        return "Invalid \(type) at '\(path)': '\(value)'"
      case .failedToInferType(let codingPath):
        let path = codingPath.map(\.stringValue).joined(separator: ".")
        return "Failed to infer plist value type at '\(path)'"
      case .invalidExplicitlyTypedValue(let type, let codingPath):
        let path = codingPath.map(\.stringValue).joined(separator: ".")
        return "Expected value of type '\(type)' at '\(path).value'"
    }
  }
}
