import Foundation

/// A utility for creating an ICNS from `.icon` files.
enum LayeredIconCreator {
  /// Creates an `AppIcon.icns` in the given directory from the given `.icon` file.
  /// - Parameters:
  ///   - icon: The input icon. Must be a `.icon` file. An error is returned
  ///     if the icon's path extension is not `icon` (case insensitive).
  ///   - outputFile: The location of the output `icns` file.
  ///   - platform: The platform the icon is being created for.
  ///   - version: The platform version the icon is being created for.
  static func createIcns(
    from icon: URL,
    outputFile: URL,
    forPlatform platform: Platform,
    withPlatformVersion version: String
  ) async throws(Error) {
    guard icon.pathExtension.lowercased() == "icon" else {
      throw Error(.notAnIconFile(icon))
    }

    let temporaryDirectory = FileManager.default.temporaryDirectory
    let workPath = temporaryDirectory.appendingPathComponent("BundlerWork-\(UUID().uuidString)")

    try FileManager.default.createDirectory(
      at: workPath,
      errorMessage: ErrorMessage.failedToCreateIconDirectory
    )

    let temporaryIcon = workPath.appendingPathComponent("AppIcon.icon")
    try Error.catch(withMessage: .failedToCopyFile(icon, temporaryIcon)) {
      try FileManager.default.copyItem(at: icon, to: temporaryIcon)
    }

    let targetDeviceArguments =
      platform
      .asApplePlatform?
      .actoolTargetDeviceNames
      .flatMap { ["--target-device", $0] } ?? []
    let process = Process.create(
      "/usr/bin/xcrun",
      arguments: [
        "actool",
        "--compile", workPath.path,
        "--enable-on-demand-resources", "NO",
        "--app-icon", "AppIcon",
        "--platform", platform.sdkName,
        "--include-all-app-icons",
        "--minimum-deployment-target", version,
      ] + targetDeviceArguments + [temporaryIcon.path]
    )
    do {
      try await process.runAndWait()
    } catch {
      // Remove the work directory before throwing.
      try? FileManager.default.removeItem(at: workPath)
      throw Error(.failedToConvertToICNS, cause: error)
    }

    let generatedIcns = workPath.appendingPathComponent("AppIcon.icns")

    guard generatedIcns.exists(withType: .file) else {
      try? FileManager.default.removeItem(at: workPath)
      throw Error(.failedToConvertToICNS)
    }

    do {
      try FileManager.default.moveItem(at: generatedIcns, to: outputFile)
    } catch {
      try? FileManager.default.removeItem(at: workPath)
      throw Error(.failedToCopyFile(generatedIcns, outputFile), cause: error)
    }

    try FileManager.default.removeItem(
      at: workPath,
      errorMessage: ErrorMessage.failedToRemoveIconDirectory
    )
  }
}
