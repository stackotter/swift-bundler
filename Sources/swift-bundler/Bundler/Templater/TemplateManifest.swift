import Foundation
import TOMLKit
import Version

/// The contents of a template's manifest file.
struct TemplateManifest: Codable {
  /// A short description of the package.
  var description: String
  /// The list of supported platforms.
  var platforms: [String]
  /// The minimum Swift version required to use the template.
  var minimumSwiftVersion: Version

  /// Loads a template's manifest file.
  /// - Parameters:
  ///   - file: The manifest file to load.
  ///   - template: The name of the template that the manifest is for.
  /// - Returns: The loaded manifest, or a failure if the file could not be read or decoded.
  static func load(from file: URL, template: String) -> Result<TemplateManifest, TemplaterError> {
    let contents: String
    do {
      contents = try String.init(contentsOf: file)
    } catch {
      return .failure(.failedToReadTemplateManifest(template: template, manifest: file, error))
    }

    let manifest: TemplateManifest
    do {
      var decoder = TOMLDecoder()

      // Set the Version decoding method to tolerant
      decoder.userInfo[.decodingMethod] = DecodingMethod.tolerant

      manifest = try decoder.decode(TemplateManifest.self, from: contents)
    } catch {
      return .failure(.failedToDecodeTemplateManifest(template: template, manifest: file, error))
    }

    return .success(manifest)
  }
}
