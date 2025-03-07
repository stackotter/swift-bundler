import ArgumentParser
import Foundation

/// The command for listing codesigning identities.
struct ListIdentitiesCommand: Command {
  static var configuration = CommandConfiguration(
    commandName: "list-identities",
    abstract: "List available codesigning identities."
  )

  func wrappedRun() async throws {
    let identities = try await CodeSigner.enumerateIdentities().unwrap()

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
