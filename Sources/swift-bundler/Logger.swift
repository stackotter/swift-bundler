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

var log = Logger(label: "Bundler") { _ in
  return Handler()
}
