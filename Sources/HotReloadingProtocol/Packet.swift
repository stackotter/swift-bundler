import Foundation

public enum Packet: Sendable {
  static let pingId: UInt64 = 0
  static let pongId: UInt64 = 1
  static let reloadDylibId: UInt64 = 2

  case ping
  case pong
  case reloadDylib(path: URL)

  var id: UInt64 {
    switch self {
      case .ping:
        return Self.pingId
      case .pong:
        return Self.pongId
      case .reloadDylib:
        return Self.reloadDylibId
    }
  }

  public static func read(from stream: inout some ReadableStream) async throws -> Self {
    let id = try await stream.readUInt64()
    switch id {
      case Self.pingId:
        return .ping
      case Self.pongId:
        return .pong
      case Self.reloadDylibId:
        let path = URL(fileURLWithPath: try await stream.readVariableString())
        return .reloadDylib(path: path)
      default:
        throw PacketError.unknownPacketId(id)
    }
  }

  public func write(to stream: inout some WritableStream) async throws {
    try await stream.writeUInt64(id)
    switch self {
      case .ping, .pong:
        break
      case let .reloadDylib(path):
        try await stream.writeVariableString(path.path)
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
