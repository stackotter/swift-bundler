import ArgumentParser
import Foundation

/// The command for listing codesigning identities.
struct ListIdentitiesCommand: ErrorHandledCommand {
  static var configuration = CommandConfiguration(
    commandName: "list-identities",
    abstract: "List available codesigning identities."
  )

  func wrappedRun() async throws(RichError<SwiftBundlerError>) {
    let identities = try await RichError<SwiftBundlerError>.catch {
      try await CodeSigner.enumerateIdentities()
    }

    Output {
      Section("Available identities") {
        KeyedList {
          for identity in identities {
            KeyedList.Entry(identity.id, "'\(identity.name)'")
          }
        }
      }
    }.show()
  }
}
