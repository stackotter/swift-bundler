import Foundation

/// The configuration for an app made with Swift Bundler v2.
struct AppConfigurationV2: Codable {
  /// The app's identifier (e.g. `com.example.ExampleApp`). Wasn't mandatory in v2, but can't be automatically migrated unless present.
  var bundleIdentifier: String
  /// The name of the executable product.
  var product: String
  /// The app's current version.
  var version: String
  // swiftlint:disable:next line_length
  /// The app's category. See [Apple's documentation](https://developer.apple.com/documentation/bundleresources/information_property_list/lsapplicationcategorytype) for more details.
  var category: String?
  /// The minimum macOS version that the app can run on.
  var minimumMacOSVersion: String?
  /// The minimum iOS version that the app can run on.
  var minimumIOSVersion: String?
  /// The path to the app's icon.
  var icon: String?
  /// A dictionary containing extra entries to add to the app's `Info.plist` file.
  ///
  /// The values can contain variable substitutions of the form `...{VARIABLE}...`.
  var extraPlistEntries: [String: String]?

  private enum CodingKeys: String, CodingKey {
    case product
    case version
    case category
    case bundleIdentifier = "bundle_identifier"
    case minimumMacOSVersion = "minimum_macos_version"
    case minimumIOSVersion = "minimum_ios_version"
    case icon
    case extraPlistEntries = "extra_plist_entries"
  }

  /// Migrates this configuration to the latest version.
  func migrate() -> AppConfiguration {
    var plist: [String: PlistValue]? = extraPlistEntries?.mapValues { value -> PlistValue in
      return .string(value)
    }

    // Update variable delimeters from '{' and '}' to '$(' and ')' (they were changed to match Xcode)
    plist = plist.map { plist in
      return plist.mapValues { value in
        return Self.updateVariableDelimeters(value)
      }
    }

    return AppConfiguration(
      identifier: bundleIdentifier,
      product: product,
      version: version,
      category: category,
      icon: icon,
      plist: plist
    )
  }

  /// Updates the variable delimeters present in any strings contained within a plist value.
  /// - Parameter value: The value to update.
  /// - Returns: The value with delimeters updated (if any were present).
  static func updateVariableDelimeters(_ value: PlistValue) -> PlistValue {
    switch value {
      case .string(let string):
        let result = VariableEvaluator.evaluateVariables(in: string, with: .custom { variable in
          return .success("$(\(variable))")
        }, openingDelimeter: "{", closingDelimeter: "}")

        switch result {
          case .success(let newValue):
            return .string(newValue)
          case .failure(let error):
            log.warning("Failed to update variable delimeters in plist value '\(string)': \(error.localizedDescription)")
            return value
        }
      case .array(let array):
        return .array(array.map { value in
          return updateVariableDelimeters(value)
        })
      case .dictionary(let dictionary):
        return .dictionary(dictionary.mapValues { value in
          return updateVariableDelimeters(value)
        })
      default:
        return value
    }
  }
}

