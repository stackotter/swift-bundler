import Logging
import Rainbow

extension Logger.Level {
  var colored: String {
    switch self {
      case .critical:
        return rawValue.red.bold
      case .error:
        return rawValue.red.bold
      case .warning:
        return rawValue.yellow.bold
      case .notice:
        return rawValue.cyan
      case .info:
        return rawValue.cyan
      case .debug:
        return rawValue.lightWhite
      case .trace:
        return rawValue.lightWhite
    }
  }
}

/// Swift Bundler's basic log handler.
struct Handler: LogHandler {
  var metadata: Logger.Metadata = [:]
  var logLevel: Logger.Level = .debug

  subscript(metadataKey key: String) -> Logger.Metadata.Value? {
    get { nil }
    set(newValue) { }
  }

  func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, source: String, file: String, function: String, line: UInt) {
    print("\(level.colored): \(message)")
  }
}

/// The global logger.
var log = Logger(label: "Bundler") { _ in
  return Handler()
}
