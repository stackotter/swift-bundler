import Foundation
import PackagePlugin

@main
struct SwiftBundlerCommandPlugin: CommandPlugin {
  /// This entry point is called when operating on a Swift package.
  func performCommand(context: PluginContext, arguments: [String]) throws {
    let bundler = try context.tool(named: "swift-bundler")

    try run(command: bundler.path, with: arguments)
  }
}

extension SwiftBundlerCommandPlugin {
  /// Run a command with the given arguments.
  func run(command: Path, with arguments: [String]) throws {
    let exec = URL(fileURLWithPath: command.string)

    let process = try Process.run(exec, arguments: arguments)
    process.waitUntilExit()

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
