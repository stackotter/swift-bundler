import Foundation
import Script

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
      case unsuccessfulExitStatus(Swift.Error)
  }

  public func run(_ command: String, _ arguments: [String]) async throws {
      let exe = try await {
          do {
              print("Running command: \(command) \(arguments.joined(separator: " "))")
              return try await executable(named: command)
          } catch {
              throw Error.commandNotFound
          }
      }()

      do {
          try await exe(arguments: arguments)
      } catch {
          throw Error.unsuccessfulExitStatus(error)
      }
  }
}
//swiftlint:enable type_name
