/// A JSON-like structure which can be traversed and modified by
/// ``VariableEvaluator``.
protocol VariableEvaluatable {
  /// Gets the value as a string if it's a string.
  var stringValue: String? { get }
  /// Gets the value as a dictionary if it's a dictionary.
  var dictionaryValue: [String: Self]? { get }
  /// Gets the value as an array if it's an array.
  var arrayValue: [Self]? { get }

  /// Creates a value representing a string.
  static func string(_ value: String) -> Self
  /// Creates a value representing an array.
  static func array(_ value: [Self]) -> Self
  /// Creates a value representing a dictionary.
  static func dictionary(_ value: [String: Self]) -> Self
}
