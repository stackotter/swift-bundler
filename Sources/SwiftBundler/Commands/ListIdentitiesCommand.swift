import Foundation
import StackOtterArgParser

/// The command for listing codesigning identities.
struct ListIdentitiesCommand: Command {
  static var configuration = CommandConfiguration(
    commandName: "list-identities",
    abstract: "List available codesigning identities."
  )

  func wrappedRun() throws {
    let identities = try CodeSigner.enumerateIdentities().unwrap()

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
