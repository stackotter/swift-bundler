import Foundation
import Logging
import Rainbow

/// The standard error stream used for logging errors.
var standardError = FileHandle.standardError

/// Swift Bundler's basic log handler.
struct Handler: LogHandler {
  var metadata: Logger.Metadata = [:]
  var logLevel: Logger.Level = .debug

  subscript(metadataKey key: String) -> Logger.Metadata.Value? {
    get { nil }
    set(newValue) { }
  }

  func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, source: String, file: String, function: String, line: UInt) {
    let output = "\(level.colored): \(message)"

    switch level {
      case .critical, .error:
        print(output, to: &standardError)
      default:
        print(output)
    }
  }
}

/// The global logger.
var log = Logger(label: "Bundler") { _ in
  return Handler()
}
