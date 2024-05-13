import Foundation

/// A utility for compiling String Catalogs (`.xcstrings` files) into a `.strings` file.
enum StringCatalogCompiler {
  /// A state for a string unit to be in.
  enum StringUnitState: String, Decodable {
    case translated = "translated"
    case needsReview = "needs_review"
  }

  /// A string unit containg a value and a state.
  struct StringUnit: Decodable {
    let state: StringUnitState
    let value: String
  }

  /// A string unit with a 'stringUnit' wrapper.
  struct StringUnitWrapper: Decodable {
    let stringUnit: StringUnit
  }

  /// Plurals in a string variation.
  struct Plurals: Decodable {
    let other: StringUnitWrapper
    let zero: StringUnitWrapper?
    let one: StringUnitWrapper?
  }

  /// Plural variation in a string variation.
  struct PluralVariation: Decodable {
    let plural: Plurals
  }

  /// String outlet: Can be string unit or plural variation.
  enum StringOutlet: Decodable {
    case unit(StringUnit)
    case variation(PluralVariation)

    enum CodingKeys: String, CodingKey {
      case variation = "variations"
      case unit = "stringUnit"
    }

    init(from decoder: Decoder) throws {
      // If it has a key "stringUnit", it's a string unit.
      // If it has a key "variation", it's a plural variation.
      let container = try decoder.container(keyedBy: CodingKeys.self)
      if let unit = try? container.decode(StringUnit.self, forKey: .unit) {
        self = .unit(unit)
      } else if let variation = try? container.decode(PluralVariation.self, forKey: .variation) {
        self = .variation(variation)
      } else {
        throw DecodingError.dataCorrupted(
          DecodingError.Context(
            codingPath: decoder.codingPath, debugDescription: "Invalid string outlet"
          )
        )
      }
    }
  }

  /// A translation unit in a string catalog.
  struct TranslationUnit: Decodable {
    let comment: String?
    let localizations: [String: StringOutlet]?
  }

  /// The root of a `.xcstrings` file.
  struct StringsCatalogFile: Decodable {
    let sourceLanguage: String
    let strings: [String: TranslationUnit]
    let version: String = "1.0"

    // Coding keys for the strings catalog file.
    private enum CodingKeys: String, CodingKey {
      case sourceLanguage
      case strings
      case version
    }

    // Make sure version is set to 1.0 when decoding.
    init(from decoder: Decoder) throws {
      // Just decode all the properties.
      let container = try decoder.container(keyedBy: CodingKeys.self)
      sourceLanguage = try container.decode(String.self, forKey: .sourceLanguage)
      strings = try container.decode([String: TranslationUnit].self, forKey: .strings)

      // Make sure version is set to 1.0 when decoding.
      let version = try container.decode(String.self, forKey: .version)
      guard version == "1.0" else {
        throw DecodingError.dataCorruptedError(
          forKey: .version, in: container, debugDescription: "Invalid version '\(version)'"
        )
      }
    }
  }

  /// A plural variation in a strings file.
  struct StringsFilePluralVariation: Encodable {
    let spec = "NSStringPluralRuleType"
    let formatValueType: String?
    let other: String
    let zero: String?
    let one: String?

    // Coding keys for the plural variations.
    private enum CodingKeys: String, CodingKey {
      case spec = "NSStringFormatSpecTypeKey"
      case formatValueType = "NSStringFormatValueTypeKey"
      case other
      case zero
      case one
    }
  }

  /// An item in a string dictionary.
  struct StringDictionaryItem: Encodable {
    let format: String = "%#@value@"
    let value: StringsFilePluralVariation

    // Coding keys for the string dictionary item.
    private enum CodingKeys: String, CodingKey {
      case format = "NSStringLocalizedFormatKey"
      case value
    }
  }

  /// Compiles a string catalog file into a strings file with data from a configuration.
  /// - Parameters:
  ///  - directory: The directory to search for string catalog files.
  ///  - outputDirectory: The directory to output the strings files to.
  ///  - keepSources: Whether to keep the source string catalog files.
  /// - Returns: A failure if an error occurs.
  static func compileStringCatalogs(
    in directory: URL,
    to outputDirectory: URL,
    keepSources: Bool = false
  ) -> Result<Void, StringCatalogCompilerError> {
    // Get the string catalog files.
    let stringCatalogFiles =
      FileManager.default.enumerator(
        at: directory,
        includingPropertiesForKeys: nil
      )?
      .compactMap { $0 as? URL }
      .filter { $0.pathExtension == "xcstrings" }

    // If there are no string catalog files, return an error.
    guard let files = stringCatalogFiles else {
      return .failure(.failedToEnumerateStringsCatalogs(directory))
    }

    // Compile the string catalog files.
    let result = compileStringCatalogs(
      files.reduce(into: [URL: String]()) { result, file in
        let tableName = file.deletingPathExtension().lastPathComponent
        result[file] = tableName
      },
      to: outputDirectory
    )

    guard case .success = result else {
      return result
    }

    // If the sources should be kept, return success.
    if keepSources {
      return .success(())
    }

    // Delete the string catalog files.
    for file in files {
      do {
        try FileManager.default.removeItem(at: file)
      } catch {
        return .failure(.failedToDeleteStringsCatalog(file, error))
      }
    }

    return .success(())
  }

  /// Compile a string catalog file into a strings file.
  /// - Parameters:
  ///  - files: The string catalog files to compile and their table names.
  ///  - outputDirectory: The directory to output the strings files to.
  /// - Returns: A failure if an error occurs.
  static func compileStringCatalogs(
    _ files: [URL: String],
    to outputDirectory: URL
  ) -> Result<Void, StringCatalogCompilerError> {
    // Create the output directory if it doesn't exist.
    if !FileManager.default.itemExists(at: outputDirectory, withType: .directory) {
      do {
        try FileManager.default.createDirectory(at: outputDirectory)
      } catch {
        return .failure(.failedToCreateOutputDirectory(outputDirectory, error))
      }
    }

    // Loop through the string catalog files.
    for (file, tableName) in files {
      // Read the string catalog file.
      let data: Result<StringsCatalogFile, StringCatalogCompilerError> = {
        do {
          let data = try Data(contentsOf: file)
          return .success(try JSONDecoder().decode(StringsCatalogFile.self, from: data))
        } catch {
          return .failure(.failedToParseJSON(file, error))
        }
      }()

      guard case let .success(data) = data else {
        return data.eraseSuccessValue()
      }

      // Get the locales
      let locales = detectLocales(from: data)

      // Generate the strings file for each locale.
      for locale in locales {
        // Create the lproj directory if it doesn't exist.
        let lprojDirectory =
          outputDirectory
          .appendingPathComponent(locale)
          .appendingPathExtension("lproj")

        // Create the lproj directory if it doesn't exist.
        if !FileManager.default.itemExists(at: lprojDirectory, withType: .directory) {
          do {
            try FileManager.default.createDirectory(at: lprojDirectory)
          } catch {
            return .failure(.failedToCreateLprojDirectory(lprojDirectory, error))
          }
        }

        let data = generateStringsFile(url: file, from: data, locale: locale)

        guard case let .success((stringsFile, stringsDictFile)) = data else {
          return data.eraseSuccessValue()
        }

        // The paths for the strings and strings dict files.
        let stringsFileURL =
          lprojDirectory
          .appendingPathComponent(tableName)
          .appendingPathExtension("strings")
        let stringsDictFileURL =
          lprojDirectory
          .appendingPathComponent(tableName)
          .appendingPathExtension("stringsdict")

        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml

        // Encode them to Plist format.
        let stringsFileData: Result<Data, StringCatalogCompilerError> = {
          do {
            return .success(try encoder.encode(stringsFile))
          } catch {
            return .failure(.failedToEncodePlistStringsFile(stringsFileURL, error))
          }
        }()
        guard case let .success(stringsFileData) = stringsFileData else {
          return stringsFileData.eraseSuccessValue()
        }

        let stringsDictFileData: Result<Data, StringCatalogCompilerError> = {
          do {
            return .success(try encoder.encode(stringsDictFile))
          } catch {
            return .failure(.failedToEncodePlistStringsDictFile(stringsDictFileURL, error))
          }
        }()
        guard case let .success(stringsDictFileData) = stringsDictFileData else {
          return stringsDictFileData.eraseSuccessValue()
        }

        // Write the strings and strings dict files.
        do {
          try stringsFileData.write(to: stringsFileURL)
          try stringsDictFileData.write(to: stringsDictFileURL)
        } catch {
          return .failure(.failedToWriteStringsFile(stringsFileURL, error))
        }
        do {
          try stringsDictFileData.write(to: stringsDictFileURL)
        } catch {
          return .failure(.failedToWriteStringsDictFile(stringsDictFileURL, error))
        }
      }
    }

    return .success(())
  }

  /// Detects locales from the string catalog files.
  /// - Parameter files: The string catalog files to detect the locales from.
  /// - Returns: The detected locales.
  static func detectLocales(from files: StringsCatalogFile) -> [String] {
    // Loop through all the strings and get the keys.
    var locales: [String] = []
    for (_, translationUnit) in files.strings {
      guard let localizations = translationUnit.localizations else {
        continue
      }

      for (locale, _) in localizations {
        locales.append(locale)
      }
    }

    return locales
  }

  // Gets the regex to match format value types.
  /// - Returns: The regex to match format value types.
  private static func getFormatValueTypeRegex() -> Result<
    NSRegularExpression, StringCatalogCompilerError
  > {
    // The regex to match format value types.
    do {
      return .success(
        try NSRegularExpression(
          pattern: "%([0-9]+\\$)?[0 #+-]?[0-9*]*\\.?\\d*[hl]{0,2}[jztL]?[dDiuUxXoOeEfgGaAcCsSpF]",
          options: []))
    } catch {
      return .failure(.failedToCreateFormatStringRegex(error))
    }
  }

  /// Selects and returns the order of format specifiers in a string.
  /// - Parameter
  ///  - fileURL: The file URL to select the order of format specifiers from.
  ///  - string: The string to select the order of format specifiers from.
  /// - Returns: The order of format specifiers in the string.
  private static func selectFormatSpecifierOrder(
    fileURL: URL,
    from string: String
  ) -> Result<[Int: (String, String)], StringCatalogCompilerError> {
    // Initialize the format specifier regex.
    let regex: NSRegularExpression
    switch getFormatValueTypeRegex() {
      case .success(let result):
        regex = result
      case .failure(let error):
        return .failure(error)
    }

    // Get the format specifiers.
    let formatSpecifiers = regex.matches(
      in: string, options: [], range: NSRange(location: 0, length: string.count)
    )
    .map { (string as NSString).substring(with: $0.range) }

    // Create a dictionary with the order of the format specifiers.
    var currentOrder = 1

    var formatSpecifierOrder = [Int: (String, String)]()

    for formatSpecifier in formatSpecifiers {
      // Trim the first character (%)
      let formatSpecifierStrip = String(formatSpecifier.dropFirst())
      // The last character is the format specifier type.
      let formatSpecifierType = String(
        formatSpecifierStrip[
          formatSpecifierStrip.index(before: formatSpecifierStrip.endIndex)
        ]
      )
      // If there is an $, get the number before it.
      let formatSpecifierOrderSplit = formatSpecifierStrip.split(separator: "$")
      let intBeforeDollar =
        formatSpecifierOrderSplit.count > 1
        ? Int(formatSpecifierOrderSplit[0])
        : nil

      // If there is a number before the $, use it as the order.
      if let intBeforeDollar = intBeforeDollar {
        if formatSpecifierOrder[intBeforeDollar] == nil {
          formatSpecifierOrder[intBeforeDollar] = (String(formatSpecifierType), formatSpecifier)
        } else if formatSpecifierOrder[intBeforeDollar]?.0 != String(formatSpecifierType) {
          return .failure(.invalidNonMatchingFormatString(URL(fileURLWithPath: ""), string))
        }
      } else {
        // If there is no number before the $, use the current order.
        if formatSpecifierOrder[currentOrder] == nil {
          formatSpecifierOrder[currentOrder] = (String(formatSpecifierType), formatSpecifier)
        } else if formatSpecifierOrder[currentOrder]?.0 != String(formatSpecifierType) {
          return .failure(.invalidNonMatchingFormatString(URL(fileURLWithPath: ""), string))
        }
        currentOrder += 1
      }
    }

    return .success(formatSpecifierOrder)
  }

  /// Generate a strings file from a String Catalog file.
  /// - Parameters:
  ///  - fileURL: The URL of the string catalog file.
  ///  - data: String Catalog file data.
  ///  - locale: The locale to generate the strings file for.
  /// - Returns: The strings file and the strings dict file.
  private static func generateStringsFile(
    url fileURL: URL,
    from data: StringsCatalogFile,
    locale: String
  ) -> Result<([String: String], [String: StringDictionaryItem]), StringCatalogCompilerError> {
    // Loop through the strings and generate the strings file.
    var stringsFile = [String: String]()
    var stringsDictFile = [String: StringDictionaryItem]()

    for (key, translationUnit) in data.strings {
      // Get the translation for the locale.
      let translation =
        translationUnit.localizations?[locale]
        ?? translationUnit.localizations?[data.sourceLanguage]

      if let translation = translation {
        // Match the translation to the correct outlet.
        switch translation {
          case .unit(let unit):
            stringsFile[key] = unit.value
          case .variation(let variation):
            // Get all the format value
            let formatValueType: [Int: (String, String)]
            switch selectFormatSpecifierOrder(
              fileURL: fileURL,
              from: variation.plural.other.stringUnit.value
            ) {
              case .success(let type):
                formatValueType = type
              case .failure(let error):
                return .failure(error)
            }

            // Get the format value type.
            var formatSpecifer = ""
            var formatSpeciferIndex: Double = .infinity
            let acceptedFormatValueTypeForNumber = [
              "d", "D", "u", "U", "x", "X", "o", "O", "f", "e", "E", "g", "G", "a", "A", "F", "i",
            ]
            for (order, type) in formatValueType {
              if Double(order) < formatSpeciferIndex
                && acceptedFormatValueTypeForNumber.contains(type.0)
              {
                formatSpecifer = type.0
                formatSpeciferIndex = Double(order)
              }
            }

            // Add the other, zero, and one variations to the strings dict file.
            stringsDictFile[key] = StringDictionaryItem(
              value: StringsFilePluralVariation(
                formatValueType: "\(Int(formatSpeciferIndex))$\(formatSpecifer)",
                other: variation.plural.other.stringUnit.value,
                zero: variation.plural.zero?.stringUnit.value,
                one: variation.plural.one?.stringUnit.value
              )
            )
        }
      } else {
        // If the translation is missing, add a placeholder to the strings file.
        stringsFile[key] = key
      }
    }

    return .success((stringsFile, stringsDictFile))
  }
}
