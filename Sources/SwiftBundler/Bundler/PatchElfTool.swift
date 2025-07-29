import Foundation

/// A wrapper around `patchelf`.
enum PatchElfTool {
  static func setRunpath(
    of elfFile: URL,
    to newRunpath: String
  ) async throws(Error) {
    let patchelf = try await Error.catch(withMessage: .patchelfNotFound) {
      try await Process.locate("patchelf")
    }

    do {
      try await Process.create(
        patchelf,
        arguments: [elfFile.path, "--set-rpath", newRunpath],
        runSilentlyWhenNotVerbose: false
      ).runAndWait()
    } catch {
      throw Error(.failedToSetRunpath(elfFile: elfFile), cause: error)
    }
  }
}
