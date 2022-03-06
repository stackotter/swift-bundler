import Foundation

/// An error during icon set creation.
enum IconError: LocalizedError {
  case icnsCreationFailed(exitStatus: Int)
  case failedToScaleIcon(newDimension: Int, Error)
  case notPNG
  case failedToCreateIconSetDirectory(Error)
  case failedToConvertToICNS(Error)
  case failedToRemoveIconSet(Error)
}

/// A utility for creating icon sets from an icon file.
enum IconSetCreator {
  /// Creates an `AppIcon.icns` in the given directory from the given 1024x1024 input png.
  /// - Parameters:
  ///   - icon: The 1024x1024 input icon. Must be a png.
  ///   - outputDirectory: The output directory to put the generated `AppIcon.icns` in.
  static func createIcns(from icon: URL, outputDirectory: URL) throws {
    guard icon.pathExtension == "png" else {
      throw IconError.notPNG
    }
    
    let iconSet = outputDirectory.appendingPathComponent("AppIcon.iconset")
    do {
      try FileManager.default.createDirectory(at: iconSet)
    } catch {
      throw IconError.failedToCreateIconSetDirectory(error)
    }
    
    let sizes = [16, 32, 128, 256, 512]
    for size in sizes {
      let regularScale = iconSet.appendingPathComponent("icon_\(size)x\(size).png")
      let doubleScale = iconSet.appendingPathComponent("icon_\(size)x\(size)@2x.png")
      try createScaledIcon(icon, size, output: regularScale)
      try createScaledIcon(icon, size * 2, output: doubleScale)
    }
    
    let process = Process.create(
      "/usr/bin/iconutil",
      arguments: ["-c", "icns", iconSet.path],
      directory: outputDirectory)
    do {
      try process.runAndWait()
    } catch {
      throw IconError.failedToConvertToICNS(error)
    }
    
    do {
      try FileManager.default.removeItem(at: iconSet)
    } catch {
      throw IconError.failedToRemoveIconSet(error)
    }
  }
  
  /// Creates a scaled copy of an icon.
  ///
  /// The output file name will be of the form `icon_{dimension}x{dimension}{fileSuffix}.png`.
  /// - Parameters:
  ///   - icon: The icon file to scale.
  ///   - dimension: The new dimension for the icon.
  ///   - output: The output file.
  private static func createScaledIcon(_ icon: URL, _ dimension: Int, output: URL) throws {
    do {
      let process = Process.create(
        "/usr/bin/sips",
        arguments: [
          "-z", String(dimension), String(dimension),
          icon.path,
          "--out", output.path
        ],
        pipe: Pipe())
      try process.runAndWait()
    } catch {
      throw IconError.failedToScaleIcon(newDimension: dimension, error)
    }
  }
}
