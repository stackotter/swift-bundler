import Foundation

/// The parsed output of an executed `Package.swift` file.
struct PackageManifest: Decodable {
  struct VersionedPlatform: Decodable {
    var name: String
    var version: String
  }

  struct Product: Decodable {
    var name: String
    var type: ProductType
  }

  enum ProductType: Decodable, Equatable {
    case executable
    case library(String)
    case unknown

    enum CodingKeys: String, CodingKey {
      case executable
      case library
    }

    init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      do {
        _ = try container.decodeNil(forKey: .executable)
        self = .executable
      } catch DecodingError.keyNotFound {
        do {
          let elements = try container.decode([String].self, forKey: .library)
          guard elements.count == 1 else {
            throw DecodingError.dataCorruptedError(
              forKey: .library,
              in: container,
              debugDescription: "Expected array of length 1"
            )
          }
          let linkingMode = elements[0]
          self = .library(linkingMode)
        } catch DecodingError.keyNotFound {
          self = .unknown
        }
      }
    }
  }

  var name: String
  var platforms: [VersionedPlatform]?
  var products: [Product]

  func platformVersion(for platform: ApplePlatform) -> String? {
    if let platformVersion = platforms?.first(where: { manifestPlatform in
      platform.manifestPlatformName == manifestPlatform.name
    })?.version {
      if platform == .macCatalyst && platformVersion == "13.0" {
        "13.1"
      } else {
        platformVersion
      }
    } else {
      nil
    }
  }
}
