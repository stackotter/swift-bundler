import Foundation
import Socket

extension Socket: ReadableStream {
  public func read(exactly count: Int) async throws -> Data {
    try await read(count)
  }
}

extension Socket: WritableStream {
  public func write(_ data: Data) async throws {
    try await sendMessage(data)
  }
}
