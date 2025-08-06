import Foundation
import ErrorKit

extension IconSetCreator {
  typealias Error = RichError<ErrorMessage>

  /// An error message related to ``IconSetCreator``.
  enum ErrorMessage: Throwable {
    case notPNG(URL)
    case failedToScaleIcon(newDimension: Int)
    case failedToCreateIconSetDirectory(URL)
    case failedToConvertToICNS
    case failedToRemoveIconSetDirectory(URL)

    var userFriendlyMessage: String {
      switch self {
        case .notPNG(let file):
          return "Icon files must be png files, and '\(file)' is not a png"
        case .failedToScaleIcon(let newDimension):
          return "Failed to scale the icon file to \(newDimension)x\(newDimension)px"
        case .failedToCreateIconSetDirectory(let directory):
          return """
            Failed to create a temporary icon set directory at '\(directory.relativePath)'
            """
        case .failedToConvertToICNS:
          return "Failed to convert the icon set directory to an 'icns' file"
        case .failedToRemoveIconSetDirectory(let directory):
          return """
            Failed to remove the temporary icon set directory at '\(directory.relativePath)'
            """
      }
    }
  }
}
