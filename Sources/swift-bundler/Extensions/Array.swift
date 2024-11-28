import Foundation
import StackOtterArgParser

// Fully qualified protocol names used to silence retroactive conformance warning
// while still supporting older Swift versions (from before the @retroactive
// marker).
extension Array: StackOtterArgParser.ExpressibleByArgument
where Element: StackOtterArgParser.ExpressibleByArgument {
  public var defaultValueDescription: String {
    "[" + self.map(\.defaultValueDescription).joined(separator: ", ") + "]"
  }

  public init?(argument: String) {
    return nil
  }
}

extension Array {
  /// A `Result`-based version of ``Array/map(_:)``. Guaranteed to
  /// short-circuit as soon as a failure occurs. Elements are processed in the
  /// order that they appear.
  func tryMap<Failure: Error, NewElement>(
    conversion convert: (Element) -> Result<NewElement, Failure>
  ) -> Result<[NewElement], Failure> {
    var result: [NewElement] = []
    for element in self {
      switch convert(element) {
        case .success(let newElement):
          result.append(newElement)
        case .failure(let error):
          return .failure(error)
      }
    }
    return .success(result)
  }

  /// A `Result`-based version of ``Array/forEach(_:)``. Guaranteed to
  /// short-circuit as soon as a failure occurs. Elements are processed in the
  /// order that they appear.
  func tryForEach<Failure: Error>(
    do action: (Element) -> Result<Void, Failure>
  ) -> Result<Void, Failure> {
    for element in self {
      switch action(element) {
        case .success:
          continue
        case .failure(let error):
          return .failure(error)
      }
    }
    return .success()
  }
}
