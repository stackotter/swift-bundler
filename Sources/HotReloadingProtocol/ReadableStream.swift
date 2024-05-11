import Foundation

public protocol ReadableStream {
  mutating func read(exactly count: Int) async throws -> Data
}

extension ReadableStream {
  public mutating func readByte() async throws -> UInt8 {
    try await readPrimitive()
  }

  public mutating func readBool() async throws -> Bool {
    try await readPrimitive()
  }

  public mutating func readUInt64() async throws -> UInt64 {
    try await readPrimitive()
  }

  public mutating func readVariableData() async throws -> Data {
    let count = try await readUInt64()
    return try await read(exactly: Int(count))
  }

  public mutating func readVariableString() async throws -> String {
    let data = try await readVariableData()
    guard let string = String(data: data, encoding: .utf8) else {
      throw ReadError.invalidUTF8
    }
    return string
  }

  public mutating func readOptional<T>(
    _ readInner: (inout Self) async throws -> T
  ) async throws -> T? {
    let isPresent = try await readBool()
    if isPresent {
      return try await readInner(&self)
    } else {
      return nil
    }
  }

  private mutating func readPrimitive<T>() async throws -> T {
    precondition(_isPOD(T.self), "T must be a plain old data type, got '\(T.self)'")
    let count = MemoryLayout<T>.stride
    let data = try await read(exactly: count)
    guard data.count == count else {
      throw ReadError.readNotExact(expected: count, actual: data.count)
    }
    return data.withUnsafeBytes { pointer in
      pointer.assumingMemoryBound(to: T.self).baseAddress!.pointee
    }
  }
}

public enum ReadError: LocalizedError {
  case invalidUTF8
  case readNotExact(expected: Int, actual: Int)

  public var errorDescription: String? {
    switch self {
      case .invalidUTF8:
        return "Invalid UTF-8"
      case let .readNotExact(expected, actual):
        return
          "read(exactly: \(expected)) didn't return exactly \(expected) bytes, got \(actual) (precondition violated)"
    }
  }
}
