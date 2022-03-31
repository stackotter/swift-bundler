import Foundation

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
#endif

SwiftBundler.main()
