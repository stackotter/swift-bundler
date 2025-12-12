import Foundation

/// A utility for creating icon sets from a `.icon` file.
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
    for platform: Platform,
    with version: String
  ) async throws(Error) {
    guard icon.pathExtension.lowercased() == "icon" else {
      throw Error(.notIconFile(icon))
    }

    let temporaryDirectory = FileManager.default.temporaryDirectory
    let workPath = temporaryDirectory.appendingPathComponent("BundlerWork-\(UUID().uuidString)")

    if workPath.exists(withType: .directory) {
      try Error.catch(withMessage: .failedToRemoveIconDirectory(workPath)) {
        try FileManager.default.removeItem(at: workPath)
      }
    }
    try FileManager.default.createDirectory(
      at: workPath,
      errorMessage: ErrorMessage.failedToCreateIconDirectory
    )

    let temporaryIcon = workPath.appendingPathComponent("AppIcon.icon")
    try Error.catch(withMessage: .failedToCopyFile(icon, temporaryIcon)) {
      try FileManager.default.copyItem(at: icon, to: temporaryIcon)
    }

    let process = Process.create(
      "/usr/bin/xcrun",
      arguments: [
        "actool",
        "--compile", workPath.path,
        "--enable-on-demand-resources", "NO",
        "--app-icon", "AppIcon",
        "--platform", platform.sdkName,
        "--enable-icon-stack-fallback-generation",
        "--include-all-app-icons",
        "--minimum-deployment-target", version,
        "--output-partial-info-plist", "/dev/null",
      ] + (platform.asApplePlatform?.targetDeviceNames.flatMap { ["--target-device", $0] } ?? [])
        + [
          temporaryIcon.path
        ]
    )
    try await Error.catch(withMessage: .failedToConvertToICNS) {
      try await process.runAndWait()
    }

    let generatedIcns = workPath.appendingPathComponent("AppIcon.icns")

    guard generatedIcns.exists(withType: .file) else {
      throw Error(.failedToConvertToICNS)
    }

    try Error.catch(withMessage: .failedToCopyFile(generatedIcns, outputFile)) {
      try FileManager.default.moveItem(at: generatedIcns, to: outputFile)
    }

    try FileManager.default.removeItem(
      at: workPath,
      errorMessage: ErrorMessage.failedToRemoveIconDirectory
    )
  }
}
