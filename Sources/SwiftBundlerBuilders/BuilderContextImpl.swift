import Foundation

// TODO: Use `package` access level when we bump to Swift 5.9
/// Implementation detail, may have breaking changes from time to time.
/// "Hidden" from users to avoid exposing implementation details such as
/// the ``Codable`` conformance, since the builder API has to be pretty
/// much perfectly backwards compatible.
public struct _BuilderContextImpl: BuilderContext, Codable {
  public var buildDirectory: URL

  public init(buildDirectory: URL) {
    self.buildDirectory = buildDirectory
  }

  enum Error: LocalizedError {
    case nonZeroExitStatus(Int)
  }

  #if os(Linux)
    private func bashQuote(_ string: String) -> String {
      let escapedContents = string.replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
        .replacingOccurrences(of: "$", with: "\\$")
        .replacingOccurrences(of: "`", with: "\\`")
      return "\"\(escapedContents)\""
    }
  #endif

  public func run(_ command: String, _ arguments: [String]) throws {
    let process = Process()
    #if os(Linux)
      // Processes often seem to hang on Linux (reproducibly) if we use /usr/bin/env
      // but not if we use /usr/bin/bash. This requires string interpolation and is
      // quite dodgy, but should have minimal impact if the quoting is incorrect
      process.executableURL = URL(fileURLWithPath: "/usr/bin/bash")
      process.arguments = [
        "-c",
        "\(bashQuote(command)) \(arguments.map(bashQuote).joined(separator: " "))",
      ]
    #else
      process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
      process.arguments = [command] + arguments
    #endif

    try process.run()
    process.waitUntilExit()

    let exitStatus = Int(process.terminationStatus)
    guard exitStatus == 0 else {
      throw Error.nonZeroExitStatus(exitStatus)
    }
  }
}
