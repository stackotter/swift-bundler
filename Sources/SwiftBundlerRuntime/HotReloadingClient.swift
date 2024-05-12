import Foundation
import HotReloadingProtocol
import Socket

public enum HotReloadingClientError: LocalizedError {
  case missingAddress
  case invalidAddress(details: String)

  public var errorDescription: String? {
    switch self {
      case .missingAddress:
        return "Missing SWIFT_BUNDLER_SERVER environment variable"
      case let .invalidAddress(details):
        return "Invalid IPv4 address string: \(details)"
    }
  }
}

public struct HotReloadingClient {
  var server: Socket

  /// Connects to the server specified by the `SWIFT_BUNDLER_SERVER` environment variable.
  /// Only supports the address formats supported by ``Self/parseAddress(_:)``.
  public init() async throws {
    guard let addressString = ProcessInfo.processInfo.environment["SWIFT_BUNDLER_SERVER"] else {
      throw HotReloadingClientError.missingAddress
    }

    let serverAddress = try Self.parseAddress(addressString)
    try await self.init(serverAddress: serverAddress)
  }

  /// Connects to a hot reloading server.
  public init(serverAddress: IPv4SocketAddress) async throws {
    server = try await Socket(IPv4Protocol.tcp)

    // TODO: Contribute to Socket to clean it up, this catch shouldn't be necessary
    do {
      try await server.connect(to: serverAddress)
    } catch Errno.socketIsConnected {}
  }

  public mutating func handlePackets(handleDylib: (Dylib) -> Void) async throws {
    while true {
      let packet: Packet
      do {
        packet = try await Packet.read(from: &server)
      } catch Errno.timedOut {
        continue
      }

      switch packet {
        case .ping:
          print("client: Received ping")
          try await Packet.pong.write(to: &server)
        case let .reloadDylib(path):
          print("client: Received new dylib")
          // Copy dylib to new partially randomized path to avoid `dlopen` just giving
          // us back the same pointer again.
          let newPath =
            path
            .deletingLastPathComponent()
            .appendingPathComponent(UUID().uuidString + ".dylib")
          try FileManager.default.copyItem(
            at: path,
            to: newPath
          )
          let dylib = try Dylib.open(newPath)
          handleDylib(dylib)
          try FileManager.default.removeItem(at: newPath)
        case .pong:
          print("client: Received pong")
      }
    }
  }

  /// Parses an IPv4 address of the form `x.x.x.x:yyyyy`.
  public static func parseAddress(_ addressString: String) throws -> IPv4SocketAddress {
    let parts = addressString.split(separator: ":")

    guard parts.count == 2 else {
      throw HotReloadingClientError.invalidAddress(details: "Must have exactly one semicolon")
    }

    guard let port = UInt16(parts[1]) else {
      throw HotReloadingClientError.invalidAddress(details: "Port must be valid UInt16")
    }

    let bytes = parts[0]
      .split(separator: ".")
      .compactMap { byteString in
        UInt8(byteString)
      }

    guard bytes.count == 4 else {
      throw HotReloadingClientError.invalidAddress(
        details: "IP address must have exactly four valid UInt8's separated by periods"
      )
    }

    return IPv4SocketAddress(
      address: IPv4Address(bytes[0], bytes[1], bytes[2], bytes[3]),
      port: port
    )
  }
}
