import Foundation

enum PlistValue: Codable {
  case string(String)
  case integer(Int)
  case double(Double)
  case bool(Bool)
  case array([PlistValue])
  case dictionary([String:PlistValue])

  var value: Any {
    switch self {
      case .string(let string):
        return string
      case .integer(let integer):
        return integer
      case .double(let double):
        return double
      case .bool(let bool):
        return bool
      case .array(let array):
        return array.map {
          $0.value
        }
      case .dictionary(let dictionary):
        return dictionary.mapValues {
          $0.value
        }
    }
  }
  
  enum CodingKeys: String, CodingKey {
    case type
    case value
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(String.self, forKey: .type)
    
    func decode<T: Decodable>() throws -> T {
      return try container.decode(T.self, forKey: .value)
    }
    
    switch type {
      case "string":
        self = .string(try decode())
      case "integer":
        self = .integer(try decode())
      case "double":
        self = .double(try decode())
      case "bool":
        self = .bool(try decode())
      case "array":
        self = .array(try decode())
      case "dictionary":
        self = .dictionary(try decode())
      default:
        throw PlistError.unknownPlistEntryType(type)
    }
  }
  
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    
    func encode<T: Encodable>(_ type: String, _ value: T) throws {
      try container.encode(type, forKey: .type)
      try container.encode(value, forKey: .value)
    }
    
    switch self {
      case .string(let string):
        try encode("string", string)
      case .integer(let integer):
        try encode("integer", integer)
      case .double(let double):
        try encode("double", double)
      case .bool(let bool):
        try encode("bool", bool)
      case .array(let array):
        try encode("array", array)
      case .dictionary(let dictionary):
        try encode("dictionary", dictionary)
    }
  }
}
