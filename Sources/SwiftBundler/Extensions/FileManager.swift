import Foundation

extension FileManager {
  /// The type of an item on the file system.
  enum ItemType {
    case file
    case directory
  }

  /// Gets whether an item of a specific type exists at the given `URL` or not.
  /// - Parameters:
  ///   - url: The URL of the item to check for.
  ///   - type: The type that the item must be.
  /// - Returns: `true` if an item of the specified type exists at the specified location.
  func itemExists(at url: URL, withType type: ItemType) -> Bool {
    var isDirectory: ObjCBool = false
    if fileExists(atPath: url.path, isDirectory: &isDirectory) {
      if isDirectory.boolValue && type == .directory {
        return true
      } else if !isDirectory.boolValue && type == .file {
        return true
      }
    }
    return false
  }

  func copyItem<E: Error>(
    at source: URL,
    to destination: URL,
    errorMessage: (
      _ source: URL,
      _ destination: URL
    ) -> E? = { _, _ in nil },
    file: String = #file,
    line: Int = #line,
    column: Int = #column
  ) throws(RichError<E>) {
    do {
      try copyItem(at: source, to: destination)
    } catch {
      throw RichError(
        errorMessage(source, destination),
        cause: error,
        file: file,
        line: line,
        column: column
      )
    }
  }

  func createDirectory(at directory: URL) throws {
    try createDirectory(
      at: directory,
      withIntermediateDirectories: true,
      attributes: nil
    )
  }

  func createDirectory<E: Error>(
    at directory: URL,
    errorMessage: (_ directory: URL) -> E? = { _ in nil },
    file: String = #file,
    line: Int = #line,
    column: Int = #column
  ) throws(RichError<E>) {
    do {
      try createDirectory(at: directory)
    } catch {
      throw RichError(
        errorMessage(directory),
        cause: error,
        file: file,
        line: line,
        column: column
      )
    }
  }

  func contentsOfDirectory(at directory: URL) throws -> [URL] {
    return try contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: nil
    )
  }

  func contentsOfDirectory<E: Error>(
    at directory: URL,
    errorMessage: (_ directory: URL) -> E? = { _ in nil },
    file: String = #file,
    line: Int = #line,
    column: Int = #column
  ) throws(RichError<E>) -> [URL] {
    do {
      return try contentsOfDirectory(at: directory)
    } catch {
      throw RichError(
        errorMessage(directory),
        cause: error,
        file: file,
        line: line,
        column: column
      )
    }
  }

  /// Creates a symlink by specifying the destination relative to the
  /// symlink. This is generally what we want to do when bundling since
  /// it allows app bundles to be relocated even if they contain symlinks.
  func createSymlink(
    at symlink: URL,
    withRelativeDestination relativeDestination: String
  ) throws {
    try createSymbolicLink(
      atPath: symlink.path,
      withDestinationPath: relativeDestination
    )
  }

  /// Creates a symlink by specifying the destination relative to the
  /// symlink. This is generally what we want to do when bundling since
  /// it allows app bundles to be relocated even if they contain symlinks.
  func createSymlink<E: Error>(
    at symlink: URL,
    withRelativeDestination relativeDestination: String,
    errorMessage: (
      _ source: URL,
      _ relativeDestination: String
    ) -> E? = { _, _ in nil },
    file: String = #file,
    line: Int = #line,
    column: Int = #column
  ) throws(RichError<E>) {
    do {
      try createSymlink(
        at: symlink,
        withRelativeDestination: relativeDestination
      )
    } catch {
      throw RichError(
        errorMessage(symlink, relativeDestination),
        cause: error,
        file: file,
        line: line,
        column: column
      )
    }
  }

  func removeItem<E: Error>(
    at item: URL,
    errorMessage: (_ item: URL) -> E? = { _ in nil },
    file: String = #file,
    line: Int = #line,
    column: Int = #column
  ) throws(RichError<E>) {
    do {
      try removeItem(at: item)
    } catch {
      throw RichError(
        errorMessage(item),
        cause: error,
        file: file,
        line: line,
        column: column
      )
    }
  }
}
