import Logging

extension Logger.Level {
  /// The log level as a colored string.
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
