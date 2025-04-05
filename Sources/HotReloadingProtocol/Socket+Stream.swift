import FlyingSocks
import Foundation

extension AsyncSocket: ReadableStream {
  public func read(exactly count: Int) async throws -> Data {
    let bytes = try await read(atMost: count)
    return Data(bytes)
  }
}

extension AsyncSocket: WritableStream {}
