import Foundation
import ErrorKit

extension StringCatalogCompiler {
  typealias Error = RichError<ErrorMessage>

  /// An error message related to ``StringCatalogCompiler``.
  enum ErrorMessage: Throwable {
    case failedToCreateFormatStringRegex
    case failedToEnumerateStringsCatalogs(URL)
    case failedToDeleteStringsCatalog(URL)
    case failedToCreateOutputDirectory(URL)
    case failedToParseJSON(URL)
    case failedToCreateLprojDirectory(URL)
    case failedToEncodePlistStringsFile(URL)
    case failedToEncodePlistStringsDictFile(URL)
    case failedToWriteStringsFile(URL)
    case failedToWriteStringsDictFile(URL)
    case invalidNonMatchingFormatString(URL, String)

    var userFriendlyMessage: String {
      switch self {
        case .failedToCreateFormatStringRegex:
          return "Failed to create format string regex"
        case .failedToEnumerateStringsCatalogs(let directory):
          return """
            Failed to enumerate strings catalogs in directory at \
            '\(directory.relativePath)'
            """
        case .failedToDeleteStringsCatalog(let file):
          return "Failed to delete strings catalog at '\(file.relativePath)'"
        case .failedToParseJSON(let file):
          return "Failed to parse JSON file at '\(file.relativePath)'"
        case .failedToCreateOutputDirectory(let directory):
          return "Failed to create output directory at '\(directory.relativePath)'"
        case .failedToCreateLprojDirectory(let directory):
          return "Failed to create lproj directory at '\(directory.relativePath)'"
        case .failedToEncodePlistStringsFile(let file):
          return "Failed to encode strings file at '\(file.relativePath)'"
        case .failedToEncodePlistStringsDictFile(let file):
          return "Failed to encode strings dict file at '\(file.relativePath)'"
        case .failedToWriteStringsFile(let file):
          return "Failed to write strings file at '\(file.relativePath)'"
        case .failedToWriteStringsDictFile(let file):
          return "Failed to write strings dict file at '\(file.relativePath)'"
        case .invalidNonMatchingFormatString(let file, let string):
          return """
            Two or more format strings in the same string do not match in file \
            '\(file.relativePath)' with string '\(string)'
            """
      }
    }
  }
}
