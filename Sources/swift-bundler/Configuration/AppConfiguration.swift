import Foundation
import Parsing

/// The configuration for an app.
struct AppConfiguration: Codable {
  /// The app's identifier (e.g. `com.example.ExampleApp`).
  var identifier: String
  /// The name of the executable product.
  var product: String
  /// The app's current version.
  var version: String
  // swiftlint:disable:next line_length
  /// The app's category. See [Apple's documentation](https://developer.apple.com/documentation/bundleresources/information_property_list/lsapplicationcategorytype) for more details.
  var category: String?
  /// The path to the app's icon.
  var icon: String?
  /// URL schemes supported by the app. Generally causes these URL schemes to get registered
  /// on app installation so that they get directed to the app system-wide.
  var urlSchemes: [String]?
  /// A dictionary containing extra entries to add to the app's `Info.plist` file.
  ///
  /// String values can contain variable substitutions (see ``VariableEvaluator`` for details).
  var plist: [String: PlistValue]?
  /// Conditionally applied configuration overlays.
  var overlays: [Overlay]?

  private enum CodingKeys: String, CodingKey {
    case identifier
    case product
    case version
    case category
    case icon
    case urlSchemes = "url_schemes"
    case plist
    case overlays
  }

  /// A flattened version of ``AppConfiguration`` (generally with all applicable
  /// overlays applied).
  struct Flat {
    var identifier: String
    var product: String
    var version: String
    var category: String?
    var icon: String?
    var urlSchemes: [String]
    var plist: [String: PlistValue]
    var dbusActivatable: Bool
  }

  struct Overlay: Codable {
    static let exclusiveProperties: [Condition: PropertySet] = [
      .platform("linux"): PropertySet()
        .add(.dbusActivatable, \.dbusActivatable)
    ]

    var condition: Condition
    var identifier: String?
    var product: String?
    var version: String?
    var category: String?
    var icon: String?
    var urlSchemes: [String]?
    var plist: [String: PlistValue]?
    var dbusActivatable: Bool?

    enum CodingKeys: String, CodingKey {
      case condition
      case identifier
      case product
      case version
      case category
      case icon
      case urlSchemes = "url_schemes"
      case plist
      case dbusActivatable = "dbus_activatable"
    }

    struct PropertySet {
      var propertyPresenceCheckers: [(name: String, checker: (Overlay) -> Bool)] = []

      func add<T>(
        _ codingKey: CodingKeys,
        _ property: KeyPath<Overlay, T?>
      ) -> PropertySet {
        var list = self
        list.propertyPresenceCheckers.append(
          (
            codingKey.rawValue,
            { overlay in
              overlay[keyPath: property] != nil
            }
          )
        )
        return list
      }

      func propertiesPresent(in overlay: Overlay) -> [String] {
        propertyPresenceCheckers.filter { (_, check) in
          check(overlay)
        }.map(\.0)
      }
    }

    enum Condition: Codable, Hashable, CustomStringConvertible {
      case platform(String)

      var description: String {
        switch self {
          case .platform(let identifier):
            return "platform(\(identifier))"
        }
      }

      init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        let parser = Parse {
          "platform("
          OneOf {
            for platform in Platform.allCases {
              platform.rawValue.map {
                platform
              }
            }
          }
          ")"
        }.map { platform in
          Condition.platform(platform.rawValue)
        }

        self = try parser.parse(value)
      }

      func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()

        let value: String
        switch self {
          case .platform(let identifier):
            value = "platform\(identifier)"
        }

        try container.encode(value)
      }
    }
  }

  /// Creates a new app configuration. Uses an `Info.plist` file to supplement missing values where possible.
  /// - Parameters:
  ///   - appName: The app's name.
  ///   - version: The app's version.
  ///   - identifier: The app's identifier (e.g. com.example.ExampleApp).
  ///   - category: The app's category identifier. See ``category``.
  ///   - infoPlistFile: An `Info.plist` file to extract missing configuration from (any non-standard keys are also added to the configuration).
  ///   - iconFile: The app's icon.
  /// - Returns: The app configuration, or a failure if an error occurs.
  static func create(
    appName: String,
    version: String?,
    identifier: String?,
    category: String?,
    infoPlistFile: URL?,
    iconFile: URL?
  ) -> Result<AppConfiguration, AppConfigurationError> {
    // Load the Info.plist file if it's provided. Use it to populate any non-specified options.
    var version = version
    var identifier = identifier
    var category = category

    let plist: [String: PlistValue]
    if let infoPlistFile = infoPlistFile {
      switch PlistValue.loadDictionary(fromPlistFile: infoPlistFile) {
        case .success(let value):
          plist = value
        case .failure(let error):
          return .failure(.failedToLoadInfoPlistEntries(file: infoPlistFile, error: error))
      }

      if version == nil, case let .string(versionString) = plist["CFBundleShortVersionString"] {
        version = versionString
      }

      if identifier == nil, case let .string(identifierString) = plist["CFBundleIdentifier"] {
        identifier = identifierString
      }

      if category == nil, case let .string(categoryString) = plist["LSApplicationCategoryType"] {
        category = categoryString
      }
    } else {
      plist = [:]
    }

    let configuration = AppConfiguration(
      identifier: identifier ?? "com.example.\(appName)",
      product: appName,
      version: version ?? "0.1.0",
      category: category,
      icon: iconFile?.lastPathComponent
    )

    return .success(
      configuration.appendingInfoPlistEntries(
        plist,
        excludeHandledKeys: true
      )
    )
  }

  /// Appends the contents of a plist dictionary to the app's Info.plist entries.
  /// - Parameters:
  ///   - dictionary: The plist dictionary to append.
  ///   - excludeHandledKeys: If `true`, entries that are already autogenerated by Swift Bundler at build are excluded.
  /// - Returns: The new configuration.
  func appendingInfoPlistEntries(
    _ dictionary: [String: PlistValue],
    excludeHandledKeys: Bool = false
  ) -> AppConfiguration {
    var filteredDictionary = dictionary
    if excludeHandledKeys {
      let excludedKeys: Set<String> = [
        "CFBundleExecutable",
        "CFBundleIdentifier",
        "CFBundleInfoDictionaryVersion",
        "CFBundleName",
        "CFBundleDisplayName",
        "CFBundlePackageType",
        "CFBundleShortVersionString",
        "CFBundleSignature",
        "CFBundleVersion",
        "LSRequiresIPhoneOS",
      ]

      filteredDictionary = dictionary.filter { key, _ in
        !excludedKeys.contains(key)
      }
    }

    var configuration = self
    configuration.plist =
      configuration.plist.map { plist in
        var plist = plist
        for (key, value) in filteredDictionary {
          plist[key] = value
        }
        return plist
      } ?? filteredDictionary

    return configuration
  }
}
