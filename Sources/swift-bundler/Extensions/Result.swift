import Foundation

extension Result {
  @discardableResult
  func unwrap() throws -> Success {
    switch self {
      case let .success(success):
        return success
      case let .failure(failure):
        throw failure
    }
  }
}

extension Result where Success == Void {
  static func success() -> Self {
    .success(())
  }
}

/// Returns a closure that runs the given operations one by one and stops on failure.
func flatten<Failure: Error>(_ operations: (() -> Result<Void, Failure>)...) -> () -> Result<Void, Failure> {
  return {
    for operation in operations {
      let result = operation()
      if case .failure(_) = result {
        return result
      }
    }
    return .success()
  }
}

/// Returns a closure that runs the given parameter expressions (using autoclosure) one by one and stops on failure.
//func flatten<Failure: Error>(_ operations: @autoclosure (() -> Result<Void, Failure>)...) -> () -> Result<Void, Failure> {
//  return {
//    for operation in operations {
//      let result = operation()
//      if case .failure(_) = result {
//        return result
//      }
//    }
//    return .success()
//  }
//}
