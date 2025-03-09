import Foundation

/// A utility containing platform-specialized operations.
enum System {
  /// Gets the application support directory for Swift Bundler.
  /// - Returns: The application support directory, or a failure if the directory couldn't be found or created.
  static func getApplicationSupportDirectory() -> Result<URL, SystemError> {
    let directory: URL
    do {
      directory = try FileManager.default.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: false
      ).appendingPathComponent("dev.stackotter.swift-bundler")
    } catch {
      return .failure(.failedToGetApplicationSupportDirectory(error))
    }

    return FileManager.default.createDirectory(at: directory)
      .mapError { error in
        .failedToCreateApplicationSupportDirectory(error)
      }
      .replacingSuccessValue(with: directory)
  }
}
