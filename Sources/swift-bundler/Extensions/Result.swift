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

  /// Perform a fallible transformation on success, but only if the given
  /// condition is met. This streamlines applicable code enough that I believe
  /// it's worth having a separate helper method for.
  func andThen(
    if condition: Bool,
    _ transform: (Success) -> Result<Success, Failure>
  ) -> Result<Success, Failure> {
    flatMap { value in
      guard condition else {
        return .success(value)
      }

      return transform(value)
    }
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

  /// If the given condition is met, perform a side effect (a fallible action
  /// which doesn't affect the underlying success value). This streamlines
  /// applicable code enough that I believe it's worth having a separate helper
  /// method for.
  func andThenDoSideEffect(
    if condition: Bool,
    _ action: (Success) -> Result<Void, Failure>
  ) -> Result<Success, Failure> {
    andThen(if: condition) { value in
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

  /// Performs an action if the result is a success, without affecting the
  /// result's value.
  func ifSuccess(do action: (Success) -> Void) -> Result<Success, Failure> {
    map { value in
      action(value)
      return value
    }
  }

  /// Attempts to recover from a failure with a function mapping the failure
  /// to a new result (with the same success value).
  func tryRecover<NewFailure>(
    _ recover: (Failure) -> Result<Success, NewFailure>
  ) -> Result<Success, NewFailure> {
    switch self {
      case .success(let value):
        return .success(value)
      case .failure(let error):
        return recover(error)
    }
  }

  /// Performs an action if the result is a failure, without affecting the
  /// result's value.
  func ifFailure(do action: (Failure) -> Void) -> Result<Success, Failure> {
    mapError { error in
      action(error)
      return error
    }
  }
}

extension Result where Failure: Equatable {
  /// Attempts to recover from a failure with a function mapping the failure
  /// to a new result (with the same success value).
  /// - Parameter badFailures: Failures that recovery shouldn't be attempted for.
  func tryRecover(
    unless badFailures: [Failure],
    _ recover: (Failure) -> Result<Success, Failure>
  ) -> Result<Success, Failure> {
    switch self {
      case .success(let value):
        return .success(value)
      case .failure(let error):
        guard !badFailures.contains(error) else {
          return .failure(error)
        }
        return recover(error)
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
