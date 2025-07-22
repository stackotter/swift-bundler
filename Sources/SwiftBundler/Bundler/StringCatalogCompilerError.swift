import Foundation
import ErrorKit

/// An error returned by ``StringCatalogCompiler``.
enum StringCatalogCompilerError: Throwable {
  case failedToCreateFormatStringRegex(Error)
  case failedToEnumerateStringsCatalogs(URL)
  case failedToDeleteStringsCatalog(URL, Error)
  case failedToCreateOutputDirectory(URL, Error)
  case failedToParseJSON(URL, Error)
  case failedToCreateLprojDirectory(URL, Error)
  case failedToEncodePlistStringsFile(URL, Error)
  case failedToEncodePlistStringsDictFile(URL, Error)
  case failedToWriteStringsFile(URL, Error)
  case failedToWriteStringsDictFile(URL, Error)
  case invalidNonMatchingFormatString(URL, String)

  var userFriendlyMessage: String {
    switch self {
      case .failedToCreateFormatStringRegex(let error):
        return "Failed to create format string regex with error '\(error)'"
      case .failedToEnumerateStringsCatalogs(let directory):
        return "Failed to enumerate strings catalogs in directory at '\(directory.relativePath)'"
      case .failedToDeleteStringsCatalog(let file, _):
        return "Failed to delete strings catalog at '\(file.relativePath)'"
      case .failedToParseJSON(let file, let error):
        return "Failed to parse JSON file at '\(file.relativePath)' with error '\(error)'"
      case .failedToCreateOutputDirectory(let directory, _):
        return "Failed to create output directory at '\(directory.relativePath)'"
      case .failedToCreateLprojDirectory(let directory, _):
        return "Failed to create lproj directory at '\(directory.relativePath)'"
      case .failedToEncodePlistStringsFile(let file, _):
        return "Failed to encode strings file at '\(file.relativePath)'"
      case .failedToEncodePlistStringsDictFile(let file, _):
        return "Failed to encode strings dict file at '\(file.relativePath)'"
      case .failedToWriteStringsFile(let file, _):
        return "Failed to write strings file at '\(file.relativePath)'"
      case .failedToWriteStringsDictFile(let file, _):
        return "Failed to write strings dict file at '\(file.relativePath)'"
      case .invalidNonMatchingFormatString(let file, let string):
        return
          "Two or more format strings in the same string do not match in file '\(file.relativePath)' with string '\(string)'"
    }
  }
}
