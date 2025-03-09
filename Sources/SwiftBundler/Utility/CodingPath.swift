import Foundation

struct CodingPath: CustomStringConvertible {
  var keys: [any CodingKey]

  init(_ keys: [any CodingKey] = []) {
    self.keys = keys
  }

  var description: String {
    keys.enumerated().map { (index, key) in
      let isFirst = index == 0
      if let intValue = key.intValue {
        return "[\(intValue)]"
      } else if isFirst {
        return key.stringValue
      } else {
        return ".\(key.stringValue)"
      }
    }.joined()
  }

  func appendingKey(_ key: any CodingKey) -> Self {
    var copy = self
    copy.keys.append(key)
    return copy
  }
}
