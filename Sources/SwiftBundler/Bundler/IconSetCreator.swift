import Foundation

/// A utility for creating icon sets from an icon file.
enum IconSetCreator {
  /// Creates an `AppIcon.icns` in the given directory from the given 1024x1024 input png.
  /// - Parameters:
  ///   - icon: The 1024x1024 input icon. Must be a png. An error is returned if the icon's path extension is not `png` (case insensitive).
  ///   - outputFile: The location of the output `icns` file.
  /// - Returns: If an error occurs, a failure is returned.
  static func createIcns(
    from icon: URL,
    outputFile: URL
  ) async -> Result<Void, IconSetCreatorError> {
    guard icon.pathExtension.lowercased() == "png" else {
      return .failure(.notPNG(icon))
    }

    let temporaryDirectory = FileManager.default.temporaryDirectory
    let iconSet = temporaryDirectory.appendingPathComponent("AppIcon.iconset")
    let sizes = [16, 32, 128, 256, 512]

    return await FileManager.default.createDirectory(at: iconSet)
      .mapError { error in
        .failedToCreateIconSetDirectory(iconSet, error)
      }
      .andThen { _ in
        await sizes.tryForEach { size in
          let regularScale = iconSet.appendingPathComponent("icon_\(size)x\(size).png")
          let doubleScale = iconSet.appendingPathComponent("icon_\(size)x\(size)@2x.png")

          return await createScaledIcon(icon, dimension: size, output: regularScale)
            .andThen { _ in
              await createScaledIcon(icon, dimension: size * 2, output: doubleScale)
            }
        }
      }
      .andThen { _ in
        await Process.create(
          "/usr/bin/iconutil",
          arguments: ["--convert", "icns", "--output", outputFile.path, iconSet.path]
        ).runAndWait().mapError { error in
          .failedToConvertToICNS(error)
        }
      }
      .andThen { _ in
        FileManager.default.removeItem(
          at: iconSet,
          onError: IconSetCreatorError.failedToRemoveIconSetDirectory
        )
      }
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
  ) async -> Result<Void, IconSetCreatorError> {
    let process = Process.create(
      "/usr/bin/sips",
      arguments: [
        "-z", String(dimension), String(dimension),
        icon.path,
        "--out", output.path,
      ],
      pipe: Pipe())

    return await process.runAndWait()
      .mapError { error in
        .failedToScaleIcon(newDimension: dimension, error)
      }
  }
}
