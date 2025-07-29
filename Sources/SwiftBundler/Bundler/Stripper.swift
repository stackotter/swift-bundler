import Foundation
import ErrorKit

enum Stripper {
  typealias Error = RichError<ErrorMessage>

  enum ErrorMessage: Throwable {
    case failedToStrip
    case failedToExtractDebugInfo

    var userFriendlyMessage: String {
      switch self {
        case .failedToStrip:
          return "Failed to strip executable"
        case .failedToExtractDebugInfo:
          return "Failed to extract debug info"
      }
    }
  }

  static func extractLinuxDebugInfo(
    from executable: URL,
    to debugInfoFile: URL
  ) async throws(Error) {
    do {
      try await Process.create(
        "objcopy",
        arguments: ["--only-keep-debug", executable.path, debugInfoFile.path]
      ).runAndWait()

      try await Process.create(
        "objcopy",
        arguments: ["--add-gnu-debuglink=\(debugInfoFile.path)", executable.path]
      ).runAndWait()
    } catch {
      throw Error(.failedToExtractDebugInfo, cause: error)
    }
  }

  static func strip(_ executable: URL) async throws(Error) {
    do {
      try await Process.create(
        "strip",
        arguments: ["-x", executable.path]
      ).runAndWait()
    } catch {
      throw Error(.failedToStrip, cause: error)
    }
  }
}
