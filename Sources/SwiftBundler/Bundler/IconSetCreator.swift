import Foundation

/// A utility for creating icon sets from an icon file.
enum IconSetCreator {
  /// Creates an `AppIcon.icns` in the given directory from the given 1024x1024 input png.
  /// - Parameters:
  ///   - icon: The 1024x1024 input icon. Must be a png. An error is returned
  ///     if the icon's path extension is not `png` (case insensitive).
  ///   - outputFile: The location of the output `icns` file.
  static func createIcns(
    from icon: URL,
    outputFile: URL
  ) async throws(Error) {
    guard icon.pathExtension.lowercased() == "png" else {
      throw Error(.notPNG(icon))
    }

    let temporaryDirectory = FileManager.default.temporaryDirectory
    let iconSet = temporaryDirectory.appendingPathComponent("AppIcon.iconset")
    let sizes = [16, 32, 128, 256, 512]

    try FileManager.default.createDirectory(
      at: iconSet,
      errorMessage: ErrorMessage.failedToCreateIconSetDirectory
    )

    for size in sizes {
      let regularScale = iconSet.appendingPathComponent("icon_\(size)x\(size).png")
      let doubleScale = iconSet.appendingPathComponent("icon_\(size)x\(size)@2x.png")

      try await createScaledIcon(icon, dimension: size, output: regularScale)
      try await createScaledIcon(icon, dimension: size * 2, output: doubleScale)
    }

    try await Error.catch(withMessage: .failedToConvertToICNS) {
      try await Process.create(
        "/usr/bin/iconutil",
        arguments: ["--convert", "icns", "--output", outputFile.path, iconSet.path]
      ).runAndWait()
    }

    try FileManager.default.removeItem(
      at: iconSet,
      errorMessage: ErrorMessage.failedToRemoveIconSetDirectory
    )
  }

  /// Creates a scaled copy of an icon.
  /// - Parameters:
  ///   - icon: The icon file to scale.
  ///   - dimension: The new dimension for the icon.
  ///   - output: The output file.
  /// - Returns: If an error occurs, a failure is returned.
  private static func createScaledIcon(
    _ icon: URL,
    dimension: Int,
    output: URL
  ) async throws(Error) {
    let process = Process.create(
      "/usr/bin/sips",
      arguments: [
        "-z", String(dimension), String(dimension),
        icon.path,
        "--out", output.path,
      ],
      pipe: Pipe()
    )

    do {
      try await process.runAndWait()
    } catch {
      throw Error(.failedToScaleIcon(newDimension: dimension), cause: error)
    }
  }
}
