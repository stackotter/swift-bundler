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
  ) throws(Error) {
    // Enumerate string catalog files.
    guard let files = FileManager.default.enumerator(
      at: directory,
      includingPropertiesForKeys: nil
    ) else {
      throw Error(.failedToEnumerateStringsCatalogs(directory))
    }

    // Filter out non-xcstrings files
    let stringCatalogFiles = files
      .compactMap { $0 as? URL }
      .filter { $0.pathExtension == "xcstrings" }

    let tableNameTable = [URL: String](
      stringCatalogFiles.map { file in
        let tableName = file.deletingPathExtension().lastPathComponent
        return (file, tableName)
      },
      uniquingKeysWith: { first, _ in first }
    )

    // Compile the string catalog files.
    try compileStringCatalogs(
      tableNameTable,
      to: outputDirectory
    )

    // Delete the string catalog files if !keepSources
    if !keepSources {
      for catalog in stringCatalogFiles {
        try FileManager.default.removeItem(
          at: catalog,
          errorMessage: ErrorMessage.failedToDeleteStringsCatalog
        )
      }
    }
  }

  /// Compile a string catalog file into a strings file.
  /// - Parameters:
  ///  - files: The string catalog files to compile and their table names.
  ///  - outputDirectory: The directory to output the strings files to.
  /// - Returns: A failure if an error occurs.
  static func compileStringCatalogs(
    _ files: [URL: String],
    to outputDirectory: URL
  ) throws(Error) {
    // Create the output directory if it doesn't exist.
    if !outputDirectory.exists(withType: .directory) {
      try FileManager.default.createDirectory(
        at: outputDirectory,
        errorMessage: ErrorMessage.failedToCreateOutputDirectory
      )
    }

    for (file, tableName) in files {
      // Read the string catalog file.
      let stringsCatalog: StringsCatalogFile
      do {
        let data = try Data.read(from: file).unwrap()
        stringsCatalog = try JSONDecoder().decode(StringsCatalogFile.self, from: data)
      } catch {
        throw Error(.failedToParseJSON(file), cause: error)
      }

      let locales = detectLocales(from: stringsCatalog)

      // Generate the strings file for each locale.
      for locale in locales {
        let lprojDirectory = outputDirectory / "\(locale).lproj"
        try generateLProj(
          at: lprojDirectory,
          stringsCatalog: stringsCatalog,
          locale: locale,
          tableName: tableName
        )
      }
    }
  }

  static func generateLProj(
    at lprojDirectory: URL,
    stringsCatalog: StringsCatalogFile,
    locale: String,
    tableName: String
  ) throws(Error) {
    if !lprojDirectory.exists(withType: .directory) {
      try FileManager.default.createDirectory(
        at: lprojDirectory,
        errorMessage: ErrorMessage.failedToCreateLprojDirectory
      )
    }

    let (stringsFile, stringsDictFile) = try generateStringsFile(
      from: stringsCatalog,
      locale: locale
    )

    let stringsFileURL = lprojDirectory / "\(tableName).strings"
    let stringsDictFileURL = lprojDirectory / "\(tableName).stringsdict"

    let encoder = PropertyListEncoder()
    encoder.outputFormat = .xml

    // Encode the files as plist
    let stringsFileData: Data
    do {
      stringsFileData = try encoder.encode(stringsFile)
    } catch {
      throw Error(.failedToEncodePlistStringsFile(stringsFileURL), cause: error)
    }

    let stringsDictFileData: Data
    do {
      stringsDictFileData = try encoder.encode(stringsDictFile)
    } catch {
      throw Error(.failedToEncodePlistStringsDictFile(stringsDictFileURL), cause: error)
    }

    // Write the strings and strings dict files.
    do {
      try stringsFileData.write(to: stringsFileURL).unwrap()
    } catch {
      throw Error(.failedToWriteStringsFile(stringsFileURL), cause: error)
    }

    do {
      try stringsDictFileData.write(to: stringsDictFileURL).unwrap()
    } catch {
      throw Error(.failedToWriteStringsDictFile(stringsDictFileURL), cause: error)
    }
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

  /// Gets the regex to match format value types.
  /// - Returns: The regex to match format value types.
  private static func getFormatValueTypeRegex() throws(Error) -> NSRegularExpression {
    try Error.catch(withMessage: .failedToCreateFormatStringRegex) {
      try NSRegularExpression(
        pattern: "%([0-9]+\\$)?[0 #+-]?[0-9*]*\\.?\\d*[hl]{0,2}[jztL]?[dDiuUxXoOeEfgGaAcCsSpF]",
        options: []
      )
    }
  }

  /// Selects and returns the order of format specifiers in a string.
  /// - Parameter
  ///  - string: The string to select the order of format specifiers from.
  /// - Returns: The order of format specifiers in the string.
  private static func selectFormatSpecifierOrder(
    from string: String
  ) throws(Error) -> [Int: (String, String)] {
    let regex = try getFormatValueTypeRegex()

    let formatSpecifiers = regex.matches(
      in: string,
      options: [],
      range: NSRange(location: 0, length: string.count)
    ).map { (string as NSString).substring(with: $0.range) }

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
          throw Error(.invalidNonMatchingFormatString(URL(fileURLWithPath: ""), string))
        }
      } else {
        // If there is no number before the $, use the current order.
        if formatSpecifierOrder[currentOrder] == nil {
          formatSpecifierOrder[currentOrder] = (String(formatSpecifierType), formatSpecifier)
        } else if formatSpecifierOrder[currentOrder]?.0 != String(formatSpecifierType) {
          throw Error(.invalidNonMatchingFormatString(URL(fileURLWithPath: ""), string))
        }
        currentOrder += 1
      }
    }

    return formatSpecifierOrder
  }

  /// Generate a strings file from a String Catalog file.
  /// - Parameters:
  ///  - data: String Catalog file data.
  ///  - locale: The locale to generate the strings file for.
  /// - Returns: The strings file and the strings dict file.
  private static func generateStringsFile(
    from data: StringsCatalogFile,
    locale: String
  ) throws(Error) -> ([String: String], [String: StringDictionaryItem]) {
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
            let formatValueType = try selectFormatSpecifierOrder(
              from: variation.plural.other.stringUnit.value
            )

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

    return (stringsFile, stringsDictFile)
  }
}
