import Foundation
import ErrorKit

enum Stripper {
  enum Error: Throwable {
    case failedToStrip(Process.Error)
    case failedToExtractDebugInfo(Process.Error)

    var userFriendlyMessage: String {
      switch self {
        case .failedToStrip(let error):
          return "Failed to strip executable: \(error.localizedDescription)"
        case .failedToExtractDebugInfo(let error):
          return "Failed to extract debug info: \(error.localizedDescription)"
      }
    }
  }

  static func extractLinuxDebugInfo(
    from executable: URL,
    to debugInfoFile: URL
  ) async -> Result<Void, Error> {
    await Result.catching { () async throws(Process.Error) in
      try await Process.create(
        "objcopy",
        arguments: ["--only-keep-debug", executable.path, debugInfoFile.path]
      ).runAndWait()
    }.andThen { _ in
      await Result.catching { () async throws(Process.Error) in
        try await Process.create(
          "objcopy",
          arguments: ["--add-gnu-debuglink=\(debugInfoFile.path)", executable.path]
        ).runAndWait()
      }
    }.mapError(Error.failedToExtractDebugInfo)
  }

  static func strip(_ executable: URL) async -> Result<Void, Error> {
    await Result.catching { () async throws(Process.Error) in
      try await Process.create(
        "strip",
        arguments: ["-x", executable.path]
      ).runAndWait()
    }.mapError(Error.failedToStrip)
  }
}
