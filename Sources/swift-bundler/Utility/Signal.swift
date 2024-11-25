#if os(macOS)
  import Darwin
#elseif os(Linux)
  import Glibc
#else
  #error("Must implement signal handling for new platforms")
#endif

#if os(macOS) || os(Linux)
  /// A signal action, typealiased to avoid confusion with the `sigaction` function.
  typealias SignalAction = sigaction

  /// A signal that can be caught.
  enum Signal: Int32, CaseIterable {
    case hangUp
    case interrupt
    case quit
    case abort
    case kill
    case alarm
    case terminate

    var rawValue: Int32 {
      switch self {
        case .hangUp: return SIGHUP
        case .interrupt: return SIGINT
        case .quit: return SIGQUIT
        case .abort: return SIGABRT
        case .kill: return SIGKILL
        case .alarm: return SIGALRM
        case .terminate: return SIGTERM
      }
    }
  }
#endif

/// Sets a trap for the specified signal.
func trap(_ signal: Signal, action: @escaping @convention(c) () -> Void) {
  #if os(macOS)
    // Modified from: https://gist.github.com/sharplet/d640eea5b6c99605ac79
    var signalAction = SignalAction(
      __sigaction_u: unsafeBitCast(action, to: __sigaction_u.self),
      sa_mask: 0,
      sa_flags: 0
    )
    sigaction(signal.rawValue, &signalAction, nil)
  #elseif os(Linux)
    var signalAction = SignalAction()
    signalAction.__sigaction_handler = unsafeBitCast(
      action,
      to: sigaction.__Unnamed_union___sigaction_handler.self
    )
    var mask = __sigset_t()
    sigemptyset(&mask)
    signalAction.sa_mask = mask
    signalAction.sa_flags = 0
    sigaction(signal.rawValue, &signalAction, nil)
  #endif
}
