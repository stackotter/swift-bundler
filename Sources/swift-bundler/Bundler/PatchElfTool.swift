import Foundation

/// A wrapper around `patchelf`.
enum PatchElfTool {
  static func setRunpath(
    of elfFile: URL,
    to newRunpath: String
  ) async -> Result<Void, PatchElfToolError> {
    await Process.locate("patchelf")
      .mapError { error in
        .patchelfNotFound(error)
      }
      .andThen { patchelf in
        let result = await Process.create(
          patchelf,
          arguments: [elfFile.path, "--set-rpath", newRunpath],
          runSilentlyWhenNotVerbose: false
        ).runAndWait()
          .mapError { error in
            PatchElfToolError.failedToSetRunpath(elfFile: elfFile, error)
          }
        return result
      }
  }
}
