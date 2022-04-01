import Foundation

extension Sequence where Element == String {
	var joinedList: String {
		ListFormatter().string(from: Array(self)) ?? self.joined(separator: ", ")
	}
}
