import Foundation

/// A utility for creating icon sets from an icon file.
enum IconSetCreator {
  /// Creates an `AppIcon.icns` in the given directory from the given 1024x1024 input png.
  /// - Parameters:
  ///   - icon: The 1024x1024 input icon. Must be a png. An error is returned if the icon's path extension is not `png` (case insensitive).
  ///   - outputDirectory: The output directory to put the generated `AppIcon.icns` in.
  /// - Returns: If an error occurs, a failure is returned.
  static func createIcns(from icon: URL, outputDirectory: URL) -> Result<Void, IconSetCreatorError> {
    guard icon.pathExtension.lowercased() == "png" else {
      return .failure(.notPNG(icon))
    }
    
    let iconSet = outputDirectory.appendingPathComponent("AppIcon.iconset")
    do {
      try FileManager.default.createDirectory(at: iconSet)
    } catch {
      return .failure(.failedToCreateIconSetDirectory(iconSet, error))
    }
    
    let sizes = [16, 32, 128, 256, 512]
    for size in sizes {
      let regularScale = iconSet.appendingPathComponent("icon_\(size)x\(size).png")
      let doubleScale = iconSet.appendingPathComponent("icon_\(size)x\(size)@2x.png")
      
      var result = createScaledIcon(icon, dimension: size, output: regularScale)
      if case .failure(_) = result {
        return result
      }
      result = createScaledIcon(icon, dimension: size * 2, output: doubleScale)
      if case .failure(_) = result {
        return result
      }
    }
    
    let process = Process.create(
      "/usr/bin/iconutil",
      arguments: ["-c", "icns", iconSet.path],
      directory: outputDirectory)
    if case let .failure(error) = process.runAndWait() {
      return .failure(.failedToConvertToICNS(error))
    }
    
    do {
      try FileManager.default.removeItem(at: iconSet)
    } catch {
      return .failure(.failedToRemoveIconSetDirectory(iconSet, error))
    }
    
    return .success()
  }
  
  /// Creates a scaled copy of an icon.
  /// - Parameters:
  ///   - icon: The icon file to scale.
  ///   - dimension: The new dimension for the icon.
  ///   - output: The output file.
  /// - Returns: If an error occurs, a failure is returned.
  private static func createScaledIcon(_ icon: URL, dimension: Int, output: URL) -> Result<Void, IconSetCreatorError> {
    let process = Process.create(
      "/usr/bin/sips",
      arguments: [
        "-z", String(dimension), String(dimension),
        icon.path,
        "--out", output.path
      ],
      pipe: Pipe())
    
    return process.runAndWait()
      .mapError { error in
        .failedToScaleIcon(newDimension: dimension, error)
      }
  }
}
