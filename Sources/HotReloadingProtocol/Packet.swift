import Foundation

public enum Packet {
  static let pingId: UInt64 = 0
  static let pongId: UInt64 = 1

  case ping
  case pong

  var id: UInt64 {
    switch self {
      case .ping:
        return Self.pingId
      case .pong:
        return Self.pongId
    }
  }

  public static func read(from stream: inout some ReadableStream) async throws -> Self {
    let id = try await stream.readUInt64()
    switch id {
      case Self.pingId:
        return .ping
      case Self.pongId:
        return .pong
      default:
        throw PacketError.unknownPacketId(id)
    }
  }

  public func write(to stream: inout some WritableStream) async throws {
    try await stream.writeUInt64(id)
    switch self {
      case .ping, .pong:
        break
    }
  }
}

public enum PacketError: LocalizedError {
  case unknownPacketId(UInt64)

  public var errorDescription: String? {
    switch self {
      case let .unknownPacketId(id):
        return "Unknown package id \(id)"
    }
  }
}
