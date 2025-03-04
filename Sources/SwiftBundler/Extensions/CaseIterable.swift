import Foundation

extension CaseIterable where Self: RawRepresentable, RawValue == String {
  /// A string containing all possible values (for use in command-line option
  /// help messages).
  static var possibleValuesDescription: String {
    "(" + Self.allCases.map(\.rawValue).joined(separator: "|") + ")"
  }
}
