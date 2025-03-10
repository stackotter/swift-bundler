import Foundation

extension Data {
  /// Reads the contents of a file, returning a result.
  static func read(from file: URL) -> Result<Data, any Error> {
    Result {
      try Data(contentsOf: file)
    }
  }

  /// Writes the data to a file, returning a result.
  func write(to file: URL) -> Result<Void, any Error> {
    Result {
      try write(to: file)
    }
  }
}
