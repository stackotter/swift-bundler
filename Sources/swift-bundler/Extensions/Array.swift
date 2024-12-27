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

struct Verb {
  var singular: String
  var plural: String

  static let be = Verb(singular: "is", plural: "are")
}

extension [String] {
  func joinedGrammatically(
    singular: String,
    plural: String,
    withTrailingVerb trailingVerb: Verb?
  ) -> String {
    let base: String
    let requiresPluralVerb: Bool
    if count == 0 {
      base = "No \(plural)"
      requiresPluralVerb = true
    } else if count == 1 {
      base = "The \(singular) \(self[0])"
      requiresPluralVerb = false
    } else {
      base = """
        The properties \(self[0..<(count - 1)].joined(separator: ", ")) \
        and \(self[count - 1])
        """
      requiresPluralVerb = true
    }

    if let trailingVerb {
      if requiresPluralVerb {
        return "\(base) \(trailingVerb.plural)"
      } else {
        return "\(base) \(trailingVerb.singular)"
      }
    } else {
      return base
    }
  }
}
