import Foundation
import ErrorKit
import SwiftBundler

#if os(macOS)
  @preconcurrency import Rainbow

  // Disable colored output if run from Xcode (the Xcode console does not support colors)
  Rainbow.enabled =
    ProcessInfo.processInfo.environment["__XCODE_BUILT_PRODUCTS_DIR_PATHS"] == nil
#endif

Process.killAllRunningProcessesOnExit()

ErrorKit.registerMapper(SwiftBundlerErrorMapper.self)

await Task { @MainActor in await SwiftBundler.main() }.value
