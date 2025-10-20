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
  /// A short summary describing the purpose of the app.
  var appDescription: String?
  /// The license type of the app.
  var license: String?
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
  /// A dictionary containing extra entries to add to the app's metadata (embedded in the
  /// main executable).
  ///
  /// String values can contain variable substitutions (see ``VariableEvaluator`` for details).
  var metadata: [String: MetadataValue]?
  /// Dependency identifiers of dependencies built by Swift Bundler before this
  /// build is invoked. Allows for integration with non-SwiftPM build tools, and
  /// applications pulling other applications (e.g. helper applications) into
  /// their build process.
  var dependencies: [Dependency]?
  /// Conditionally applied configuration overlays.
  var overlays: [Overlay]?

  /// Only available in overlays with `platform(linux)` or stronger. Sets whether
  /// Swift Bundler generates a D-Bus service file for the application or not.
  var dbusActivatable = false

  /// Only available in overlays with `bundler(linuxRPM)` or stronger. Sets the list of
  /// package dependencies
  var rpmRequirements: [String] = []

  /// Only available in overlays with `platform(macCatalyst)` or stronger. Sets
  /// the interface idiom used by Mac Catalyst.
  var catalystInterfaceIdiom: MacCatalystInterfaceIdiom = .ipad

  private enum CodingKeys: String, CodingKey {
    case identifier
    case product
    case version
    case appDescription = "description"
    case license
    case category
    case icon
    case urlSchemes = "url_schemes"
    case plist
    case metadata
    case overlays
    case dependencies
  }

  /// A flattened version of ``AppConfiguration`` (generally with all applicable
  /// overlays applied).
  struct Flat {
    var identifier: String
    var product: String
    var version: String
    var appDescription: String?
    var license: String?
    var category: String?
    var icon: String?
    var urlSchemes: [String]
    var plist: [String: PlistValue]
    var metadata: [String: MetadataValue]
    var dependencies: [Dependency]
    var dbusActivatable: Bool
    var rpmRequirements: [String]
    var catalystInterfaceIdiom: MacCatalystInterfaceIdiom
  }

  struct Dependency: Codable, Hashable {
    var project: String
    var product: String

    var identifier: String {
      "\(project).\(product)"
    }

    init(project: String, product: String) {
      self.project = project
      self.product = product
    }

    init(from decoder: any Decoder) throws {
      let container = try decoder.singleValueContainer()
      let parser = OneOf {
        Parse {
          PrefixUpTo(".")
          "."
          Rest<Substring>()
        }.map { project, product in
          Dependency(
            project: String(project),
            product: String(product)
          )
        }

        Parse {
          Rest<Substring>()
        }.map { product in
          Dependency(
            project: ProjectConfiguration.rootProjectName,
            product: String(product)
          )
        }
      }
      let value = try container.decode(String.self)
      self = try parser.parse(value)
    }

    func encode(to encoder: any Encoder) throws {
      var container = encoder.singleValueContainer()
      try container.encode(identifier)
    }
  }

  /// The interface idiom to be used by Catalyst apps.
  enum MacCatalystInterfaceIdiom: String, Codable {
    case ipad
    case mac
  }

  struct Overlay: Codable, ConfigurationOverlay {
    typealias Base = AppConfiguration

    static let exclusiveProperties: [OverlayCondition: PropertySet<Self>] = [
      .platform("linux"): PropertySet()
        .add(.dbusActivatable, \.dbusActivatable),
      .bundler("linuxRPM"): PropertySet()
        .add(.rpmRequirements, \.rpmRequirements),
      .platform("macCatalyst"): PropertySet()
        .add(.catalystInterfaceIdiom, \.catalystInterfaceIdiom)
    ]

    var condition: OverlayCondition
    var identifier: String?
    var product: String?
    var version: String?
    var appDescription: String?
    var license: String?
    var category: String?
    var icon: String?
    var urlSchemes: [String]?
    var plist: [String: PlistValue]?
    var metadata: [String: MetadataValue]?
    var dependencies: [Dependency]?
    var dbusActivatable: Bool?
    var rpmRequirements: [String]?
    var catalystInterfaceIdiom: MacCatalystInterfaceIdiom?

    enum CodingKeys: String, CodingKey {
      case condition
      case identifier
      case product
      case version
      case appDescription = "description"
      case license
      case category
      case icon
      case urlSchemes = "url_schemes"
      case plist
      case metadata
      case dependencies
      case dbusActivatable = "dbus_activatable"
      case rpmRequirements = "requirements"
      case catalystInterfaceIdiom = "interface_idiom"
    }

    func merge(into base: inout Base) {
      Self.merge(&base.identifier, identifier)
      Self.merge(&base.product, product)
      Self.merge(&base.version, version)
      Self.merge(&base.appDescription, appDescription)
      Self.merge(&base.license, license)
      Self.merge(&base.category, category)
      Self.merge(&base.icon, icon)
      Self.merge(&base.urlSchemes, urlSchemes)
      Self.merge(&base.plist, plist)
      Self.merge(&base.metadata, metadata)
      Self.merge(&base.dependencies, dependencies)
      Self.merge(&base.dbusActivatable, dbusActivatable)
      Self.merge(&base.rpmRequirements, rpmRequirements)
      Self.merge(&base.catalystInterfaceIdiom, catalystInterfaceIdiom)
    }
  }

  /// Creates a new app configuration. Uses an `Info.plist` file to supplement
  /// missing values where possible.
  /// - Parameters:
  ///   - appName: The app's name.
  ///   - version: The app's version.
  ///   - identifier: The app's identifier (e.g. com.example.ExampleApp).
  ///   - category: The app's category identifier. See ``category``.
  ///   - infoPlistFile: An `Info.plist` file to extract missing configuration
  ///     from (any non-standard keys are also added to the configuration).
  ///   - iconFile: The app's icon.
  /// - Returns: The app configuration, or a failure if an error occurs.
  static func create(
    appName: String,
    version: String?,
    identifier: String?,
    category: String?,
    infoPlistFile: URL?,
    iconFile: URL?
  ) throws(Error) -> AppConfiguration {
    // Load the Info.plist file if it's provided. Use it to populate any non-specified options.
    var version = version
    var identifier = identifier
    var category = category

    let plist: [String: PlistValue]
    if let infoPlistFile {
      do {
        plist = try PlistValue.loadDictionary(fromPlistFile: infoPlistFile)
      } catch {
        throw Error(.failedToLoadInfoPlistEntries(file: infoPlistFile), cause: error)
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

    return configuration.appendingInfoPlistEntries(
      plist,
      excludeHandledKeys: true
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

extension AppConfiguration.Flat {
  var appDescriptionOrDefault: String {
    appDescription ?? "None"
  }

  var licenseOrDefault: String {
    license ?? "Unknown"
  }
}
