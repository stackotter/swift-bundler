import Foundation
import Parsing

/// A utility for codesigning Darwin application bundles
enum CodeSigner {
  struct Identity {
    var id: String
    var name: String
  }

  static func sign(bundle: URL, identity: Identity) -> Result<Void, CodeSignerError> {
    let process = Process.create(
      "/usr/bin/codesign",
      arguments: [
        "--force", "--deep",
        "--sign", identity.id,
        bundle.path
      ]
    )

    return process.runAndWait()
      .mapError { error in
        .failedToRunCodesignTool(error)
      }
  }

  static func enumerateIdentities() -> Result<[Identity], CodeSignerError> {
    let process = Process.create(
      "/usr/bin/security",
      arguments: ["find-identity", "-pcodesigning", "-v"]
    )

    return process.getOutput()
      .mapError { error in
        return .failedToEnumerateIdentities(error)
      }
      .flatMap { output in
        // Example input: `52635337831A02427192D4FC5EC8528323456F17 "Apple Development: stackotter@stackotter.dev (LK3JHG2345)"`
        let identityParser = Parse {
          PrefixThrough(") ").map(String.init)
          PrefixUpTo(" ").map(String.init)
          " "
          OneOf {
            PrefixUpTo("\n")
            Rest()
          }.map { substring in
            // Remove quotation marks
            substring.dropFirst().dropLast()
          }.map(String.init)
        }.map { _, id, name in
          return Identity(id: id, name: name)
        }

        let identityListParser = Many {
          identityParser
        }

        let identities: [Identity]
        do {
          identities = try identityListParser.parse(output)
        } catch {
          return .failure(.failedToParseIdentityList(error))
        }

        return .success(identities)
      }
  }
}
