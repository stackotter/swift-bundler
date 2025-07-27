import Foundation

// TODO: Create test for this
extension Sequence where Element == String {
  var joinedList: String {
    var output = ""
    let array = Array(self)
    for (index, item) in array.enumerated() {
      if index == array.count - 1 {
        output += "and "
      }
      output += String(describing: item)
      if index != array.count - 1 {
        output += ", "
      }
    }
    return output
  }
}

extension Array where Element == UInt8 {
  init?(fromHex hex: String) {
    guard hex.count % 2 == 0 else {
      return nil
    }

    self = []
    for index in 0..<(hex.count / 2) {
      let start = hex.index(hex.startIndex, offsetBy: index * 2)
      let end = hex.index(start, offsetBy: 2)
      guard let byte = UInt8(hex[start..<end], radix: 16) else {
        return nil
      }
      self.append(byte)
    }
  }
}
