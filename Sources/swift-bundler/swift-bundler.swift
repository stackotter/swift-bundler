import Foundation
import Rainbow
import SwiftBundler

#if os(Linux)
  import Glibc
#endif

@main
struct Main {
  static func main() async {
    Process.killAllRunningProcessesOnExit()

    #if os(macOS)
      // Disable colored output if run from Xcode (the Xcode console does not support colors)
      Rainbow.enabled =
        ProcessInfo.processInfo.environment["__XCODE_BUILT_PRODUCTS_DIR_PATHS"] == nil
    #endif

    await SwiftBundler.main()
  }
}
