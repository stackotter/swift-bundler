import SwiftBundler
import class Foundation.Process

#if os(Linux)
  import Glibc
#elseif os(Windows)
  import WinSDK
#elseif os(macOS)
  import Rainbow
  import class Foundation.ProcessInfo
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
