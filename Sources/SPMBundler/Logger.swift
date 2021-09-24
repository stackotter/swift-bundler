import DeltaLogger
import Logging

struct Handler: LogHandler {
  var metadata: Logger.Metadata = [:]
  var logLevel: Logger.Level = .debug
  
  subscript(metadataKey key: String) -> Logger.Metadata.Value? {
    get { nil }
    set(newValue) { }
  }

  func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, source: String, file: String, function: String, line: UInt) {
    print("\(level): \(message)")
  }
}

extension Logger.Level {
  var shortString: String {
    switch self {
    case .debug:
      return "debug"
    case .info:
      return "info"
    case .critical:
      return "critical"
    case .error:
      return "error"
    case .notice:
      return "note"
    case .trace:
      return "trace"
    case .warning:
      return "warn"
    }
  }
}

var log = Logger(label: "Bundler") { _ in
  return Handler()
}