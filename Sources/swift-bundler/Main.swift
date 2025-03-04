import SwiftBundler
import Foundation
import Rainbow

#if os(Linux)
import Glibc
#endif

@main
struct Main {
    static func main() {
        // Kill all running processes on exit
        for signal in Signal.allCases {
            trap(signal) {
                for process in processes {
                    process.terminate()
                }
#if os(Linux)
                for pid in appImagePIDs {
                    kill(pid, SIGKILL)
                }
#endif
                Foundation.exit(1)
            }
        }

#if os(macOS)
        // Disable colored output if run from Xcode (the Xcode console does not support colors)
        Rainbow.enabled =
        ProcessInfo.processInfo.environment["__XCODE_BUILT_PRODUCTS_DIR_PATHS"] == nil
#endif

        SwiftBundler.main()
    }
}

