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
