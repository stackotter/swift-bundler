import Foundation
import PackagePlugin

@main
struct SwiftBundlerCommandPlugin: CommandPlugin {
  /// This entry point is called when operating on a Swift package.
  func performCommand(context: PluginContext, arguments: [String]) async throws {
    let bundler = try context.tool(named: "swift-bundler")

    try await run(command: bundler.path, with: arguments)
  }
}

extension SwiftBundlerCommandPlugin {
  /// Run a command with the given arguments.
  func run(command: Path, with arguments: [String]) async throws {
    let exec = URL(fileURLWithPath: command.string)

    let process = try await Process.runAndWait(exec, arguments: arguments)

    // Check whether the subprocess invocation was successful.
    if process.terminationReason == .exit,
      process.terminationStatus == 0
    {
      print("SwiftBundlerCommandPlugin successfully completed.")
    } else {
      let problem = "\(process.terminationReason):\(process.terminationStatus)"
      Diagnostics.error("SwiftBundlerCommandPlugin failed: \(problem)")
    }
  }
}

extension Process {
  class func runAndWait(_ url: URL, arguments: [String]) async throws -> Process {
    try await withCheckedThrowingContinuation { c in
      do {
        _ = try Process.run(url, arguments: arguments) {
          c.resume(returning: $0)
        }
      } catch {
        c.resume(throwing: error)
      }
    }
  }
}
