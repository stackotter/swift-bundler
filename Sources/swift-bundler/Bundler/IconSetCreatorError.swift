import Foundation

/// An error returned by ``IconSetCreator``.
enum IconSetCreatorError: LocalizedError {
  case notPNG(URL)
  case failedToScaleIcon(newDimension: Int, ProcessError)
  case failedToCreateIconSetDirectory(URL, Error)
  case failedToConvertToICNS(ProcessError)
  case failedToRemoveIconSetDirectory(URL, Error)
  
  var errorDescription: String? {
    switch self {
      case .notPNG(let file):
        return "Icon files must be png files, and '\(file.relativePath)' is not a png"
      case .failedToScaleIcon(let newDimension, let processError):
        return "Failed to scale the icon file to \(newDimension)x\(newDimension)px: \(processError.localizedDescription)"
      case .failedToCreateIconSetDirectory(let directory, _):
        return "Failed to create a temporary icon set directory at '\(directory.relativePath)'"
      case .failedToConvertToICNS(let processError):
        return "Failed to convert the icon set directory to an 'icns' file: \(processError.localizedDescription)"
      case .failedToRemoveIconSetDirectory(let directory, _):
        return "Failed to remove the temporary icon set directory at '\(directory.relativePath)'"
    }
  }
}
