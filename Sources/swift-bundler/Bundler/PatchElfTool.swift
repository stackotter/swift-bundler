import Foundation

/// A warpper around `patchelf`.
enum PatchElfTool {
  static func setRunpath(
    of elfFile: URL,
    to newRunpath: String
  ) -> Result<Void, PatchElfToolError> {
    Process.locate("patchelf")
      .mapError { error in
        .patchelfNotFound(error)
      }
      .flatMap { patchelf in
        let result = Process.create(
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
