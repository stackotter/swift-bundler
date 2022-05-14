import Foundation
import Rainbow

@main
struct AsyncMain {
  static func main() async {
    #if os(macOS)
    // Kill all running processes on exit
    for signal in Signal.allCases {
      trap(signal) { _ in
        for process in processes {
          process.terminate()
        }
        Foundation.exit(1)
      }
    }

    // Disable colored output if run from Xcode (the Xcode console does not support colors)
    Rainbow.enabled = ProcessInfo.processInfo.environment["__XCODE_BUILT_PRODUCTS_DIR_PATHS"] == nil
    #endif

    await SwiftBundler.main()
  }
}
