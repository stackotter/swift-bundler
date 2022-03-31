import Foundation

// Kill all running processes on exit
#if os(macOS)
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
