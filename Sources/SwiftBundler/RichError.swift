import ErrorKit
import Foundation

/// A simple error consisting of a single string description.
struct StringError: Throwable {
  var userFriendlyMessage: String
}

/// The location in the codebase. Used to track error origination.
struct Location: CustomStringConvertible {
  var file: String
  var line: Int
  var column: Int

  var description: String {
    "\(URL(fileURLWithPath: file).lastPathComponent):\(line):\(column)"
  }
}

/// A rich error. Provides a chain of blame without requiring additional
/// cumbersome `caught` enum cases.
struct RichError<Message: Error>: Throwable, RichErrorProtocol {
  var message: Message?
  var cause: (any Error)?
  var location: Location

  var erasedMessage: (any Error)? {
    message
  }

  var messageType: any Error.Type {
    Message.self
  }

  /// Creates a rich error from a message and an optional underlying cause.
  init(
    _ message: Message,
    cause: (any Error)? = nil,
    file: String = #file,
    line: Int = #line,
    column: Int = #column
  ) {
    self.message = message
    self.cause = cause
    self.location = Location(file: file, line: line, column: column)
  }

  init(cause: any Error, file: String = #file, line: Int = #line, column: Int = #column) {
    self.message = nil
    self.cause = cause
    self.location = Location(file: file, line: line, column: column)
  }

  static func `catch`<R>(
    do body: () throws -> R,
    file: String = #file,
    line: Int = #line,
    column: Int = #column
  ) throws(Self) -> R {
    do {
      return try body()
    } catch let error as Message {
      throw Self(error, file: file, line: line, column: column)
    } catch {
      throw Self(cause: error, file: file, line: line, column: column)
    }
  }

  static func `catch`<R>(
    do body: () async throws -> R,
    file: String = #file,
    line: Int = #line,
    column: Int = #column
  ) async throws(Self) -> R {
    do {
      return try await body()
    } catch let error as Message {
      throw Self(error, file: file, line: line, column: column)
    } catch {
      throw Self(cause: error, file: file, line: line, column: column)
    }
  }

  var userFriendlyMessage: String {
    if let message {
      return ErrorKit.userFriendlyMessage(for: message)
    } else if let cause {
      return ErrorKit.userFriendlyMessage(for: cause)
    } else {
      // Unlikely to reach unless the user manually sets the message or cause to
      // nil after using one of the two available initializers.
      return "\(Message.self)"
    }
  }
}

extension Throwable {
  func becauseOf(_ error: any Error) -> RichError<Self> {
    RichError(self, cause: error)
  }
}

extension RichError where Message == StringError {
  /// Creates a rich error from a string description and an optional underlying
  /// cause.
  init(
    _ message: String,
    cause: (any Error)? = nil,
    file: String = #file,
    line: Int = #line,
    column: Int = #column
  ) {
    self.message = StringError(userFriendlyMessage: message)
    self.cause = cause
    self.location = Location(file: file, line: line, column: column)
  }
}

extension RichError {
  private static func initHelper<T: Error>(_ existingCause: T, cause: any Error) -> RichError<T> {
    RichError<T>(existingCause, cause: cause)
  }

  func becauseOf(_ cause: any Error) -> Self {
    var richError = self
    if let existingCause = richError.cause {
      richError.cause = Self.initHelper(existingCause, cause: cause)
    } else {
      richError.cause = cause
    }
    return richError
  }
}

protocol RichErrorProtocol: Throwable {
  var erasedMessage: (any Error)? { get }
  var messageType: any Error.Type { get }
  var cause: (any Error)? { get }
  var location: Location { get }
}

// Adapted from https://github.com/FlineDev/ErrorKit to understand RichError
func chainDescription(for error: Error, verbose: Bool, indent: String = "") -> String {
  let enclosingType = type(of: error)
  let mirror = Mirror(reflecting: error)

  func niceDescription(of value: Any) -> String {
    let typeName = "\(type(of: value))"
    let isTuple = typeName.hasPrefix("(") && typeName != "().self"
    if isTuple {
      let mirror = Mirror(reflecting: value)
      let values = mirror.children.map(\.value)
      let descriptions = values.map(niceDescription(of:))
      let labels: [String] = mirror.children.map(\.label).compactMap { label in
        if label?.hasPrefix(".") != false {
          return nil
        } else {
          return label
        }
      }
      if labels.count == descriptions.count {
        return "(\(zip(labels, descriptions).map { "\($0): \($1)" }.joined(separator: ", ")))"
      } else {
        return "(\(descriptions.joined(separator: ", ")))"
      }
    } else if let url = value as? URL {
      return "\"\(url.path(relativeTo: URL.currentDirectory))\""
    } else if let error = value as? any Error {
      return "\"\(ErrorKit.userFriendlyMessage(for: error))\""
    } else {
      return String(reflecting: value)
    }
  }

  func enumAssociatedValueDescription(value: Any) -> String {
    let description = niceDescription(of: value)
    // Surround with parentheses
    if !description.hasPrefix("(") {
      return "(\(description))"
    } else {
      return description
    }
  }

  // Helper function to format the type name with optional metadata
  func typeDescription(_ error: (any Error)?, type: any Error.Type) -> String {
    let typeName = String(describing: type)

    if let error {
      let mirror = Mirror(reflecting: error)
      if mirror.displayStyle != .enum {
        return "\(typeName)"
      } else {
        let caseName = mirror.children.first?.label ?? String(describing: error)
        if verbose {
          let value = enumAssociatedValueDescription(value: mirror.children.first?.value ?? ())
          return "\(enclosingType).\(caseName)\(value)"
        } else {
          // Only show the enum case's name, without its associated value.
          return "\(enclosingType).\(caseName)"
        }
      }
    } else {
      return "\(typeName)"
    }
  }

  let nextIndent = indent + "   "
  if let error = error as? RichErrorProtocol {
    let typeDescription = typeDescription(error.erasedMessage, type: error.messageType)
    if let cause = error.cause {
      if let message = error.erasedMessage {
        return """
          \(typeDescription) @ \(error.location)
          \(indent)└─ userFriendlyMessage: "\(ErrorKit.userFriendlyMessage(for: message))"
          \(indent)└─ \(chainDescription(for: cause, verbose: verbose, indent: nextIndent))
          """
      } else {
        return """
          \(typeDescription) @ \(error.location)
          \(indent)└─ \(chainDescription(for: cause, verbose: verbose, indent: nextIndent))
          """
      }
    } else {
      return """
        \(typeDescription) @ \(error.location)
        \(indent)└─ userFriendlyMessage: "\(error.userFriendlyMessage)"
        """
    }
  } else if
    error is Catching,
    let caughtError = mirror.children.first(where: { $0.label == "caught" })?.value as? Error
  {
    return """
      \(typeDescription(error, type: type(of: error)))
      \(indent)└─ \(chainDescription(for: caughtError, verbose: verbose, indent: nextIndent))
      """
  } else {
    // This is a leaf node
    return """
      \(typeDescription(error, type: type(of: error)))
      \(indent)└─ userFriendlyMessage: \"\(ErrorKit.userFriendlyMessage(for: error))\"
      """
  }
}
