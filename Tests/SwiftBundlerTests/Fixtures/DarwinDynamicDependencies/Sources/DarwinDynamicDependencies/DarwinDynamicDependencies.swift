import Sparkle
import Library

@main
struct DarwinDynamicDependencies {
    static func main() {
        let sum = Library.add(a: 2, b: 3)
        print("2 + 3 = \(sum)")
        let comparison = SUStandardVersionComparator.default.compareVersion("1.0.0", toVersion: "1.0.1")
        print("1.0.0 > 1.0.1 = \(comparison == .orderedDescending)")
    }
}
