#if SUPPORT_HOT_RELOADING
  import Foundation
  import FileSystemWatcher
  import FlyingSocks
  import HotReloadingProtocol

  #if canImport(Darwin)
    import Darwin
  #elseif canImport(Glibc)
    import Glibc
  #elseif canImport(WinSDK)
    import WinSDK.WinSock2
  #endif

  struct HotReloadingServer {
    let port: UInt16
    let socket: AsyncSocket

    enum Error: LocalizedError {
      case failedToSendPing(Swift.Error)
      case expectedPong(Packet)
      case addrInUse
      case failedToCreateSocket(Swift.Error)
      case failedToAcceptConnection(Swift.Error)
      case failedToWatchPackage(Swift.Error)

      var errorDescription: String? {
        switch self {
          case .failedToSendPing(let error):
            return "Failed to send ping: \(error.localizedDescription)"
          case .expectedPong(let response):
            return "Expected pong, got '\(response)'"
          case .addrInUse:
            return "Failed to create socket: Address in use"
          case .failedToCreateSocket(let error):
            return "Failed to create socket: \(error.localizedDescription)"
          case .failedToAcceptConnection(let error):
            return "Failed to accept connection: \(error.localizedDescription)"
          case .failedToWatchPackage(let error):
            return "Failed to watch package: \(error.localizedDescription)"
        }
      }
    }

    static func create(portHint: UInt16 = 7331) async -> Result<Self, Error> {
      var port = portHint

      // Attempt to create socket and if the address is already in use, retry with
      // higher and higher ports until socket creation fails for another reason or
      // a free address is found.
      while true {
        switch await Self.createSocket(port: port) {
          case .success(let socket):
            return .success(Self(port: port, socket: socket))
          case .failure(.addrInUse):
            port += 1
          case .failure(let error):
            return .failure(error)
        }
      }
    }

    static func createSocket(port: UInt16) async -> Result<AsyncSocket, Error> {
      do {
        // FlyingSocks relies on type inference tricks to hide away sockaddr_in,
        // but using them here breaks our Linux CI, so just spell it out and hope
        // FlyingSocks doesn't break this if/when they introduce more Swifty
        // SocketAddress wrappers (which would be very welcome regardless).
        let address = try sockaddr_in.inet(ip4: "127.0.0.1", port: port)
        let socket = try Socket(domain: Int32(type(of: address).family))
        try socket.bind(to: address)
        try socket.listen()

        let pool = SocketPool.make()
        try await pool.prepare()
        Task {
          try await pool.run()
        }

        let asyncSocket = try AsyncSocket(
          socket: socket,
          pool: pool
        )
        return .success(asyncSocket)
      } catch let error as SocketError {
        let addrInUse: Int32
        #if canImport(Darwin) || canImport(Glibc)
          addrInUse = EADDRINUSE
        #elseif canImport(WinSDK)
          addrInUse = WSAEADDRINUSE
        #endif

        guard
          case let .failed(_, errno, _) = error,
          errno == addrInUse
        else {
          return .failure(.failedToCreateSocket(error))
        }

        return .failure(.addrInUse)
      } catch {
        return .failure(.failedToCreateSocket(error))
      }
    }

    func start(
      product: String,
      buildContext: SwiftPackageManager.BuildContext
    ) async -> Result<(), Error> {
      var connection: AsyncSocket
      switch await accept() {
        case .success(let value):
          connection = value
        case .failure(let error):
          return .failure(error)
      }

      log.debug("Received connection from runtime")

      return await Self.handshake(&connection).andThen { _ in
        log.debug("Handshake succeeded")
        let sourcesDirectory = buildContext.genericContext.projectDirectory / "Sources"
        return await Result {
          try await FileSystemWatcher.watch(
            paths: [sourcesDirectory.path],
            with: {
              log.info("Building 'lib\(product).dylib'")
              let connection = connection
              Task {
                do {
                  var connection = connection
                  let dylibFile = try await SwiftPackageManager.buildExecutableAsDylib(
                    product: product,
                    buildContext: buildContext
                  ).unwrap()
                  log.info("Successfully built dylib")

                  try await Packet.reloadDylib(path: dylibFile).write(to: &connection)
                } catch {
                  log.error("Hot reloading failed: \(error.localizedDescription)")
                }
              }
            },
            errorHandler: { error in
              log.error("Hot reloading failed: \(error.localizedDescription)")
            }
          )
        }
        .mapError(Error.failedToWatchPackage)
      }
    }

    func accept() async -> Result<AsyncSocket, Error> {
      await Result {
        try await socket.accept()
      }.mapError(Error.failedToAcceptConnection)
    }

    static func handshake(_ connection: inout AsyncSocket) async -> Result<(), Error> {
      await Result {
        try await Packet.ping.write(to: &connection)
        return try await Packet.read(from: &connection)
      }.mapError(Error.failedToSendPing).andThen { response in
        guard case Packet.pong = response else {
          return .failure(.expectedPong(response))
        }
        return .success()
      }
    }
  }
#endif
