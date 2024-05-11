import Foundation

public protocol WritableStream {
  mutating func write(_ data: Data) async throws
}

extension WritableStream {
  public mutating func writeByte(_ value: UInt8) async throws {
    try await writePrimitive(value)
  }

  public mutating func writeBool(_ value: Bool) async throws {
    try await writePrimitive(value)
  }

  public mutating func writeUInt64(_ value: UInt64) async throws {
    try await writePrimitive(value)
  }

  public mutating func writeVariableData(_ data: Data) async throws {
    let count = UInt64(data.count)
    try await writeUInt64(count)
    try await write(data)
  }

  public mutating func writeVariableString(_ string: String) async throws {
    guard let data = string.data(using: .utf8) else {
      throw WriteError.invalidUTF8
    }
    try await writeVariableData(data)
  }

  public mutating func writeOptional<T>(
    _ value: T?,
    _ writeInner: (inout Self, T) async throws -> Void
  ) async throws {
    if let value = value {
      try await writeBool(true)
      try await writeInner(&self, value)
    } else {
      try await writeBool(false)
    }
  }

  private mutating func writePrimitive<T>(_ value: T) async throws {
    precondition(_isPOD(T.self), "T must be a plain old data type, got '\(T.self)'")
    let count = MemoryLayout<T>.stride
    let data = withUnsafePointer(to: value) { pointer in
      Data(bytes: pointer, count: count)
    }
    try await write(data)
  }
}

public enum WriteError: LocalizedError {
  case invalidUTF8

  public var errorDescription: String? {
    switch self {
      case .invalidUTF8:
        return "Invalid UTF-8"
    }
  }
}
