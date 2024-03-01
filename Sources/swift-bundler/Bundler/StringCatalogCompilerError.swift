import Foundation
/// An error returned by ``StringCatalogCompiler``.
enum StringCatalogCompilerError: LocalizedError {
  case failedToEnumerateStringsCatalogs(URL, Error)
  case failedToDeleteStringsCatalog(URL, Error)
  case failedToCreateOutputDirectory(URL, Error)
  case failedToParseJSON(URL, Error)
  case failedToCreateLprojDirectory(URL, Error)
  case failedToEncodePlistStringsFile(URL, Error)
  case failedToEncodePlistStringsDictFile(URL, Error)
  case failedToWriteStringsFile(URL, Error)
  case failedToWriteStringsDictFile(URL, Error)

  var errorDescription: String? {
    switch self {
      case .failedToEnumerateStringsCatalogs(let directory, _):
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
    }
  }
}
