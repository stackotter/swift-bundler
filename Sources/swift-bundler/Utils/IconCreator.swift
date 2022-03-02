//import Foundation
//
///// An error during icon set creation.
//enum IconError: LocalizedError {
//  /// Failed to create the icns for the app.
//  case icnsCreationFailed(exitStatus: Int)
//}
//
///// A utility for creating icon sets from an icon file.
//enum IconUtil {
//  /// Creates an AppIcon.icns in the given directory from the given 1024x1024 input png.
//  static func createIcns(from icon1024: URL, outDir: URL) throws {
//    let iconPath = icon1024.escapedPath
//    let iconSetPath = outDir.appendingPathComponent("AppIcon.iconset").escapedPath
//    let exitStatus = Shell.getExitStatus("""
//mkdir \(iconSetPath)
//sips -z 16 16     \(iconPath) --out \(iconSetPath)/icon_16x16.png
//sips -z 32 32     \(iconPath) --out \(iconSetPath)/icon_16x16@2x.png
//sips -z 32 32     \(iconPath) --out \(iconSetPath)/icon_32x32.png
//sips -z 64 64     \(iconPath) --out \(iconSetPath)/icon_32x32@2x.png
//sips -z 128 128   \(iconPath) --out \(iconSetPath)/icon_128x128.png
//sips -z 256 256   \(iconPath) --out \(iconSetPath)/icon_128x128@2x.png
//sips -z 256 256   \(iconPath) --out \(iconSetPath)/icon_256x256.png
//sips -z 512 512   \(iconPath) --out \(iconSetPath)/icon_256x256@2x.png
//sips -z 512 512   \(iconPath) --out \(iconSetPath)/icon_512x512.png
//cp \(iconPath) \(iconSetPath)/icon_512x512@2x.png
//iconutil -c icns \(iconSetPath)
//rm -R \(iconSetPath)
//""", silent: true)
//    if exitStatus != 0 {
//      throw IconError.icnsCreationFailed(exitStatus: exitStatus)
//    }
//  }
//}
