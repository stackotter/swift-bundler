import Logging

extension Logger.Level {
  /// The log level as a colored string.
  func coloring(_ string: String) -> String {
    switch self {
      case .critical:
        return string.red.bold
      case .error:
        return string.red.bold
      case .warning:
        return string.yellow.bold
      case .notice:
        return string.cyan
      case .info:
        return string.cyan
      case .debug:
        return string.lightWhite
      case .trace:
        return string.lightWhite
    }
  }
}
