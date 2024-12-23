import Foundation
import TOMLKit

/// A representation of a property list value suitable for losslessly encoding and decoding
/// to and from formats such as JSON and TOML.
///
/// When a value can not be losslessly encoded as a regular single value, it is encoded as
/// a dictionary containing a `type` field and a `value` field. This ensures that the original
/// type is not lost and allows every single possible plist value to be losslessly stored in
/// formats such as JSON or TOML. Below is an example of an explicitly typed date value:
///
/// ```json
/// {
///   "type": "date",
///   "value": "2022-05-18T00:54:55Z"
/// }
/// ```
enum PlistValue: Codable, Equatable, VariableEvaluatable {
  /// The JSON schema for a plist value.
  private static var schema = """
    {
      "type": ["number", "string", "object", "array", "boolean"]
    }
    """

  case dictionary([String: PlistValue])
  case array([PlistValue])
  case real(Double)
  case integer(Int)
  case boolean(Bool)
  case date(Date)
  case data(Data)
  case string(String)

  var stringValue: String? {
    switch self {
      case .string(let value):
        return value
      default:
        return nil
    }
  }

  var dictionaryValue: [String: PlistValue]? {
    switch self {
      case .dictionary(let value):
        return value
      default:
        return nil
    }
  }

  var arrayValue: [PlistValue]? {
    switch self {
      case .array(let value):
        return value
      default:
        return nil
    }
  }

  /// A string representation of the value's explicit type.
  var type: String {
    switch self {
      case .dictionary:
        return "dict"
      case .array:
        return "array"
      case .real:
        return "real"
      case .integer:
        return "integer"
      case .boolean:
        return "boolean"
      case .date:
        return "date"
      case .data:
        return "data"
      case .string:
        return "string"
    }
  }

  /// `true` if an explicit type is required to unambiguously decode the value.
  var requiresExplicitType: Bool {
    switch self {
      case .data:
        return true
      case .dictionary(let dictionary):
        // Avoid confusing the dictionary for an explicitly typed value.
        return dictionary[CodingKeys.type.rawValue] != nil
      case .real(let number):
        // Avoid interpreting the real number as an integer
        return Double(Int(number)) == number
      case .array, .integer, .boolean, .date, .string:
        return false
    }
  }

  /// This value's value represented using regular Swift types. Used when serializing to plist.
  var value: Any {
    switch self {
      case .dictionary(let dictionary):
        return dictionary.mapValues(\.value)
      case .array(let array):
        return array.map(\.value)
      case .real(let double):
        return double
      case .integer(let integer):
        return integer
      case .boolean(let boolean):
        return boolean
      case .date(let date):
        return date
      case .data(let data):
        return data
      case .string(let string):
        return string
    }
  }

  /// Coding keys used by explicitly typed value containers.
  enum CodingKeys: String, CodingKey {
    case type
    case value
  }

  // swiftlint:disable:next cyclomatic_complexity
  init(from decoder: Decoder) throws {
    // Attempt to decode the value as an explicitly typed value.
    if let container = try? decoder.container(keyedBy: CodingKeys.self) {
      if let value = try Self.decodeExplicitlyTypedValue(from: container) {
        self = value
        return
      }
    }

    // Attempt to infer the type of the implicitly typed value.
    if let container = try? decoder.singleValueContainer() {
      if let string = try? container.decode(String.self) {
        if let date = ISO8601DateFormatter().date(from: string) {
          self = .date(date)
        } else {
          self = .string(string)
        }
      } else if let integer = try? container.decode(Int.self) {
        self = .integer(integer)
      } else if let number = try? container.decode(Double.self) {
        if Double(Int(number)) == number {
          self = .integer(Int(number))
        } else {
          self = .real(number)
        }
      } else if let boolean = try? container.decode(Bool.self) {
        self = .boolean(boolean)
      } else if let array = try? container.decode([PlistValue].self) {
        self = .array(array)
      } else if let dictionary = try? container.decode([String: PlistValue].self) {
        self = .dictionary(dictionary)
      } else {
        throw PlistError.failedToInferType(codingPath: decoder.codingPath)
      }
    } else {
      throw PlistError.failedToInferType(codingPath: decoder.codingPath)
    }
  }

  /// Decodes a value with an explicit type.
  ///
  /// Below is an example of an explicitly typed value (in JSON form):
  ///
  /// ```json
  /// {
  ///   "type": "date",
  ///   "value": "2022-05-18T00:54:55Z"
  /// }
  /// ```
  static func decodeExplicitlyTypedValue(  // swiftlint:disable:this cyclomatic_complexity
    from container: KeyedDecodingContainer<CodingKeys>
  ) throws -> PlistValue? {
    let type: String
    do {
      type = try container.decode(String.self, forKey: .type)
    } catch {
      return nil
    }

    do {
      switch type {
        case "dict":
          return .dictionary(try container.decode([String: PlistValue].self, forKey: .value))
        case "array":
          return .array(try container.decode([PlistValue].self, forKey: .value))
        case "real":
          return .real(try container.decode(Double.self, forKey: .value))
        case "integer":
          return .integer(try container.decode(Int.self, forKey: .value))
        case "boolean":
          return .boolean(try container.decode(Bool.self, forKey: .value))
        case "date":
          let string = try container.decode(String.self, forKey: .value)
          guard let date = ISO8601DateFormatter().date(from: string) else {
            throw PlistError.invalidValue(
              string, type: "ISO8601 date", codingPath: container.codingPath
            )
          }
          return .date(date)
        case "data":
          let base64 = try container.decode(String.self, forKey: .value)
          guard let data = Data(base64Encoded: base64) else {
            throw PlistError.invalidValue(
              base64, type: "base64 data", codingPath: container.codingPath
            )
          }
          return .data(data)
        case "string":
          return .string(try container.decode(String.self, forKey: .value))
        default:
          throw PlistError.invalidValue(
            type, type: "plist data type", codingPath: container.codingPath
          )
      }
    } catch {
      if let error = error as? PlistError {
        throw error
      }
      throw PlistError.invalidExplicitlyTypedValue(type: type, codingPath: container.codingPath)
    }
  }

  func encode(to encoder: Encoder) throws {
    let valueEncoder: Encoder
    if requiresExplicitType {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(type, forKey: .type)
      valueEncoder = container.superEncoder(forKey: .value)
    } else {
      valueEncoder = encoder
    }

    switch self {
      case .dictionary(let dictionary):
        try dictionary.encode(to: valueEncoder)
      case .array(let array):
        try array.encode(to: valueEncoder)
      case .real(let real):
        try real.encode(to: valueEncoder)
      case .integer(let integer):
        try integer.encode(to: valueEncoder)
      case .boolean(let boolean):
        try boolean.encode(to: valueEncoder)
      case .date(let date):
        let string = ISO8601DateFormatter().string(from: date)
        try string.encode(to: valueEncoder)
      case .data(let data):
        let string = data.base64EncodedString()
        try string.encode(to: valueEncoder)
      case .string(let string):
        try string.encode(to: valueEncoder)
    }
  }

  /// Loads a dictionary of ``PlistValue``s from a plist file.
  /// - Parameter plistFile: The plist file to load the dictionary from.
  /// - Returns: The loaded plist dictionary, or a failure if an error occurs.
  static func loadDictionary(
    fromPlistFile plistFile: URL
  ) -> Result<[String: PlistValue], PlistError> {
    let contents: Data
    do {
      contents = try Data(contentsOf: plistFile)
    } catch {
      return .failure(.failedToReadInfoPlistFile(error))
    }

    let dictionary: [String: Any]
    do {
      var propertyListFormat = PropertyListSerialization.PropertyListFormat.xml
      guard
        let plist = try PropertyListSerialization.propertyList(
          from: contents,
          options: .mutableContainersAndLeaves,
          format: &propertyListFormat
        ) as? [String: Any]
      else {
        return .failure(.failedToDeserializePlistFileContents(contents, nil))
      }

      dictionary = plist
    } catch {
      return .failure(.failedToDeserializePlistFileContents(contents, error))
    }

    return convert(dictionary)
  }

  /// Converts a Swift dictionary to a dictionary of ``PlistValue``s.
  /// - Parameter value: The value to convert.
  /// - Returns: The converted value, or a failure if the value is invalid.
  static func convert(_ dictionary: [String: Any]) -> Result<[String: PlistValue], PlistError> {
    var convertedDictionary: [String: PlistValue] = [:]
    for (key, value) in dictionary {
      switch convert(value) {
        case .success(let convertedValue):
          convertedDictionary[key] = convertedValue
        case .failure(let error):
          return .failure(error)
      }
    }
    return .success(convertedDictionary)
  }

  /// Converts a Swift value to a ``PlistValue``.
  /// - Parameter value: The value to convert.
  /// - Returns: The converted value, or a failure if the value is invalid.
  static func convert(_ value: Any) -> Result<PlistValue, PlistError> {  // swiftlint:disable:this cyclomatic_complexity
    let convertedValue: PlistValue
    if let string = value as? String {
      convertedValue = .string(string)
    } else if let date = value as? Date {
      convertedValue = .date(date)
    } else if let integer = value as? Int {
      convertedValue = .integer(integer)
    } else if let double = value as? Double {
      convertedValue = .real(double)
    } else if let boolean = value as? Bool {
      convertedValue = .boolean(boolean)
    } else if let array = value as? [Any] {
      var convertedArray: [PlistValue] = []
      for element in array {
        switch convert(element) {
          case .success(let convertedElement):
            convertedArray.append(convertedElement)
          case .failure(let error):
            return .failure(error)
        }
      }
      convertedValue = .array(convertedArray)
    } else if let dictionary = value as? [String: Any] {
      switch convert(dictionary) {
        case .success(let convertedDictionary):
          convertedValue = .dictionary(convertedDictionary)
        case .failure(let error):
          return .failure(error)
      }
    } else {
      return .failure(.invalidPlistValue(value))
    }

    return .success(convertedValue)
  }
}
