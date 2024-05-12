import Foundation

extension DispatchQueue {
  static func runOnMainThread(_ action: () throws -> Void) rethrows {
    if Thread.isMainThread {
      try action()
    } else {
      try DispatchQueue.main.sync {
        try action()
      }
    }
  }
}
