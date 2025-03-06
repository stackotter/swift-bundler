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
  func migrate() async -> AppConfiguration {
    var plist: [String: PlistValue]? = extraPlistEntries?.mapValues { value -> PlistValue in
      return .string(value)
    }

    // Update variable delimiters from '{' and '}' to '$(' and ')' (they were changed to match Xcode)
    plist = await plist.asyncMap { plist in
      return await plist.asyncMapValues { value in
        return await Self.updateVariableDelimiters(value)
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

  /// Updates the variable delimiters present in any strings contained within a plist value.
  /// - Parameter value: The value to update.
  /// - Returns: The value with delimiters updated (if any were present).
  static func updateVariableDelimiters(_ value: PlistValue) async -> PlistValue {
    switch value {
      case .string(let string):
        let result = await VariableEvaluator.evaluateVariables(
          in: string,
          with: .custom { variable in
            return .success("$(\(variable))")
          },
          openingDelimiter: "{",
          closingDelimiter: "}"
        )

        switch result {
          case .success(let newValue):
            return .string(newValue)
          case .failure(let error):
            log.warning(
              "Failed to update variable delimiters in plist value '\(string)': \(error.localizedDescription)"
            )
            return value
        }
      case .array(let array):
        return .array(
          await array.asyncMap { value in
            return await updateVariableDelimiters(value)
          }
        )
      case .dictionary(let dictionary):
        return await .dictionary(
          dictionary.asyncMapValues { value in
            return await updateVariableDelimiters(value)
          }
        )
      default:
        return value
    }
  }
}

extension Sequence where Element: Sendable {
  public func asyncMap<T>(_ transform: @Sendable (Element) async throws -> T) async rethrows -> [T]
  {
    let initialCapacity = underestimatedCount
    var result = ContiguousArray<T>()
    result.reserveCapacity(initialCapacity)

    var iterator = self.makeIterator()

    // Add elements up to the initial capacity without checking for regrowth.
    for _ in 0..<initialCapacity {
      result.append(try await transform(iterator.next()!))
    }
    // Add remaining elements, if any.
    while let element = iterator.next() {
      result.append(try await transform(element))
    }
    return Array(result)
  }
}

extension Optional {
  func asyncMap<T>(_ transform: (Wrapped) async throws -> T) async rethrows -> T? {
    switch self {
      case .none:
        return nil
      case .some(let value):
        return try await transform(value)
    }
  }
}

extension Dictionary {
  func asyncMapValues<T>(_ transform: (Value) async throws -> T) async rethrows -> [Key: T] {
    var result: [Key: T] = .init(minimumCapacity: count)
    for (key, value) in self {
      result[key] = try await transform(value)
    }

    return result
  }
}
