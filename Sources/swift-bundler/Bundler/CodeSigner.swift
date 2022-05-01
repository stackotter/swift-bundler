import Foundation
import Parsing

/// A utility for codesigning Darwin application bundles
enum CodeSigner {
  /// An identity that can be used to codesign a bundle.
  struct Identity {
    /// The identity's id.
    var id: String
    /// The identity's display name.
    var name: String
  }
  
  /// Signs a Darwin app bundle.
  /// - Parameters:
  ///   - bundle: The bundle to sign.
  ///   - identityId: The id of the codesigning identity to use.
  /// - Returns: A failure if the `codesign` command fails to run.
  static func sign(bundle: URL, identityId: String) -> Result<Void, CodeSignerError> {
    log.info("Codesigning executable")
    let process = Process.create(
      "/usr/bin/codesign",
      arguments: [
        "--force", "--deep",
        "--sign", identityId,
        bundle.path
      ]
    )

    return process.runAndWait()
      .mapError { error in
        return .failedToRunCodesignTool(error)
      }
  }
  
  /// Enumerates the user's available codesigning identities.
  /// - Returns: An array of identities, or a failure if the `security` command fails or produces invalid output.
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
