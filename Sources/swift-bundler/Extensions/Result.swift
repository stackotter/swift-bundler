import Foundation

extension Result {
  /// A utility for allowing `Result` to be used with APIs that require errors to be thrown.
  /// - Returns: The success value if the result is a success.
  /// - Throws: The error if the result is a failure.
  @discardableResult func unwrap() throws -> Success {
    switch self {
      case let .success(success):
        return success
      case let .failure(failure):
        throw failure
    }
  }

  /// The result as a success (`nil` if the result is a failure).
  var success: Success? {
    switch self {
      case let .success(success):
        return success
      case .failure:
        return nil
    }
  }

  /// The result as a failure (`nil` if the result is a success).
  var failure: Failure? {
    switch self {
      case .success:
        return nil
      case let .failure(failure):
        return failure
    }
  }

  /// Changes the success value type to void.
  func eraseSuccessValue() -> Result<Void, Failure> {
    switch self {
      case .success:
        return .success()
      case .failure(let error):
        return .failure(error)
    }
  }

  func intoAnyError() -> Result<Success, any Error> {
    mapError { error in
      error
    }
  }

  /// Just a better name for ``Result/flatMap``. When skim reading complicated
  /// code it's not always clear whether it's an array `flatMap` or a result
  /// `flatMap`. In my opinion, it's best if you can tell what you're working
  /// with straight away.
  func andThen<NewSuccess>(
    _ transform: (Success) -> Result<NewSuccess, Failure>
  ) -> Result<NewSuccess, Failure> {
    flatMap(transform)
  }

  /// Specifically just performs a side effect without affecting the underlying
  /// success value of the result (unless of course the action fails).
  func andThenDoSideEffect(
    _ action: (Success) -> Result<Void, Failure>
  ) -> Result<Success, Failure> {
    andThen { value in
      action(value).map { _ in
        value
      }
    }
  }

  /// If the result is a success, then this replaces the success value. It leaves
  /// failures unchanged except for their type.
  func replacingSuccessValue<NewSuccess>(
    with newValue: NewSuccess
  ) -> Result<NewSuccess, Failure> {
    map { _ in
      newValue
    }
  }
}

extension Result where Success == Void {
  /// A convenience method for specifying a success when `Success` is `Void`.
  /// - Returns: A success value.
  static func success() -> Self {
    .success(())
  }
}

/// Returns a closure that runs the given operations one by one and stops on failure.
/// - Parameter operations: The operations to chain together.
/// - Returns: If an error occurs, a failure is returned.
func flatten<Failure: Error>(
  _ operations: (() -> Result<Void, Failure>)...
) -> (() -> Result<Void, Failure>) {
  return {
    for operation in operations {
      let result = operation()
      if case .failure = result {
        return result
      }
    }
    return .success()
  }
}

/// Returns a closure that runs the given operations one by one and stops on failure.
/// - Parameter operations: The operations to chain together.
/// - Returns: If an error occurs, a failure is returned.
func flatten<Failure: Error>(
  _ operations: (() async -> Result<Void, Failure>)...
) -> (() async -> Result<Void, Failure>) {
  return {
    for operation in operations {
      let result = await operation()
      if case .failure = result {
        return result
      }
    }
    return .success()
  }
}
