import Foundation
import ErrorKit

/// An error returned by ``IconSetCreator``.
enum IconSetCreatorError: Throwable {
  case notPNG(URL)
  case failedToScaleIcon(newDimension: Int, Process.Error)
  case failedToCreateIconSetDirectory(URL, Error)
  case failedToConvertToICNS(Process.Error)
  case failedToRemoveIconSetDirectory(URL, Error)

  var userFriendlyMessage: String {
    switch self {
      case .notPNG(let file):
        return "Icon files must be png files, and '\(file)' is not a png"
      case .failedToScaleIcon(let newDimension, let processError):
        return
          "Failed to scale the icon file to \(newDimension)x\(newDimension)px: \(processError.localizedDescription)"
      case .failedToCreateIconSetDirectory(let directory, _):
        return "Failed to create a temporary icon set directory at '\(directory.relativePath)'"
      case .failedToConvertToICNS(let processError):
        return
          "Failed to convert the icon set directory to an 'icns' file: \(processError.localizedDescription)"
      case .failedToRemoveIconSetDirectory(let directory, _):
        return "Failed to remove the temporary icon set directory at '\(directory.relativePath)'"
    }
  }
}
