import Foundation
import ErrorKit

/// An error that can occur while encoding or decoding a ``PlistValue``.
enum PlistError: Throwable {
  case invalidValue(String, type: String, codingPath: [CodingKey])
  case failedToInferType(codingPath: [CodingKey])
  case invalidExplicitlyTypedValue(type: String, codingPath: [CodingKey])
  case failedToDeserializePlistFileContents(Data, Error?)
  case failedToReadInfoPlistFile(Error)
  case invalidPlistValue(description: String)

  var userFriendlyMessage: String {
    switch self {
      case .invalidValue(let value, let type, let codingPath):
        let path = CodingPath(codingPath)
        return "Invalid \(type) at '\(path)': '\(value)'"
      case .failedToInferType(let codingPath):
        let path = CodingPath(codingPath)
        return "Failed to infer plist value type at '\(path)'"
      case .invalidExplicitlyTypedValue(let type, let codingPath):
        let path = CodingPath(codingPath)
        return "Expected value of type '\(type)' at '\(path).value'"
      case .failedToDeserializePlistFileContents:
        return "Failed to deserialize contents"
      case .failedToReadInfoPlistFile:
        return "Failed to read info plist file"
      case .invalidPlistValue(let description):
        return "Invalid value found in plist: '\(description)'"
    }
  }
}
