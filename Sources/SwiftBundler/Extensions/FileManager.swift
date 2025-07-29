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

  /// Swift Bundler commonly copies items and wraps up the source, destination,
  /// and underlying error into a use-case-specific error type. This helper
  /// reduces the amount of boilerplate required to do so.
  func copyItem<Failure: Error>(
    at source: URL,
    to destination: URL,
    onError wrapError: (
      _ source: URL,
      _ destination: URL,
      _ error: Error
    ) -> Failure = { _, _, error in error }
  ) -> Result<Void, Failure> {
    do {
      try copyItem(at: source, to: destination)
      return .success()
    } catch {
      return .failure(wrapError(source, destination, error))
    }
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

  /// Creates a directory, returning a result.
  ///
  /// See ``FileManager/copyItem(at:to:onError:)`` above for why this exists.
  func createDirectory<Failure>(
    at directory: URL,
    onError wrapError: (
      _ directory: URL,
      _ error: Error
    ) -> Failure = { _, error in error }
  ) -> Result<Void, Failure> {
    Result {
      try createDirectory(
        at: directory,
        withIntermediateDirectories: true,
        attributes: nil
      )
    }.mapError { error in
      wrapError(directory, error)
    }
  }

  func createDirectory<E: Error>(
    at directory: URL,
    errorMessage: (_ directory: URL) -> E? = { _ in nil },
    file: String = #file,
    line: Int = #line,
    column: Int = #column
  ) throws(RichError<E>) {
    do {
      try createDirectory(
        at: directory,
        withIntermediateDirectories: true,
        attributes: nil
      )
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

  /// See ``FileManager/copyItem(at:to:onError:)`` above for why this exists.
  func contentsOfDirectory<Failure: Error>(
    at directory: URL,
    onError wrapError: (
      _ directory: URL,
      _ error: Error
    ) -> Failure = { _, error in error }
  ) -> Result<[URL], Failure> {
    do {
      let contents = try FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil
      )
      return .success(contents)
    } catch {
      return .failure(wrapError(directory, error))
    }
  }

  func contentsOfDirectory<E: Error>(
    at directory: URL,
    errorMessage: (_ directory: URL) -> E? = { _ in nil },
    file: String = #file,
    line: Int = #line,
    column: Int = #column
  ) throws(RichError<E>) -> [URL] {
    do {
      let contents = try FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil
      )
      return contents
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

  /// See ``FileManager/copyItem(at:to:onError:)`` above for why this exists.
  func moveItem<Failure: Error>(
    at source: URL,
    to destination: URL,
    onError wrapError: (
      _ source: URL,
      _ destination: URL,
      _ error: Error
    ) -> Failure = { _, _, error in error }
  ) -> Result<Void, Failure> {
    do {
      try moveItem(at: source, to: destination)
      return .success()
    } catch {
      return .failure(wrapError(source, destination, error))
    }
  }

  /// Creates a symlink by specifying the destination relative to the
  /// symlink. This is generally what we want to do when bundling since
  /// it allows app bundles to be relocated even if they contain symlinks.
  ///
  /// See ``FileManager/copyItem(at:to:onError:)`` for information about
  /// the `wrapError` parameter.
  func createSymlink<Failure: Error>(
    at symlink: URL,
    withRelativeDestination relativeDestination: String,
    onError wrapError: (
      _ source: URL,
      _ relativeDestination: String,
      _ error: Error
    ) -> Failure = { _, _, error in error }
  ) -> Result<Void, Failure> {
    do {
      try FileManager.default.createSymbolicLink(
        atPath: symlink.path,
        withDestinationPath: relativeDestination
      )
      return .success()
    } catch {
      return .failure(wrapError(symlink, relativeDestination, error))
    }
  }

  /// Removes an item on disk.
  ///
  /// See ``FileManager/copyItem(at:to:onError:)`` for information about
  /// the `wrapError` parameter.
  func removeItem<Failure: Error>(
    at item: URL,
    onError wrapError: (
      _ item: URL,
      _ error: Error
    ) -> Failure = { _, error in error }
  ) -> Result<Void, Failure> {
    Result {
      try FileManager.default.removeItem(at: item)
    }.mapError { error in
      wrapError(item, error)
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
      try FileManager.default.removeItem(at: item)
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
