import Foundation
import SwiftCommand

//swiftlint:disable type_name
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
      case commandNotFound
      case unsuccessfulExitStatus(ExitStatus)
  }

  public func run(_ command: String, _ arguments: [String]) async throws {
    guard let command = Command.findInPath(withName: command) else {
      throw Error.commandNotFound
    }

    let exitStatus = try await command.addArguments(arguments).status

    guard exitStatus.terminatedSuccessfully else {
      throw Error.unsuccessfulExitStatus(exitStatus)
    }
  }
}
//swiftlint:enable type_name
