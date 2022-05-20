import Foundation
import SwiftXcodeProj

extension XcodeprojConverter {
  struct XcodeFile {
    var path: String
    var sourceTree: PBXSourceTree
    var parent: PBXFileElement?

    func absolutePath(sourceRoot: URL) -> Result<URL, XcodeprojConverterError> {
      switch sourceTree {
        case .absolute:
          return .success(URL(fileURLWithPath: path))
        default:
          return relativePath().map { relativePath in
            return sourceRoot.appendingPathComponent(relativePath)
          }
      }
    }

    func relativePath() -> Result<String, XcodeprojConverterError> {
      switch sourceTree {
        case .absolute:
          return .success(URL(fileURLWithPath: path).lastPathComponent)
        case .sourceRoot:
          return .success(path)
        case .group:
          guard let parent = parent, let sourceTree = parent.sourceTree else {
            return .success(path)
          }

          let parentGroup = XcodeFile(
            path: parent.path ?? "",
            sourceTree: sourceTree,
            parent: parent.parent
          )

          return parentGroup.relativePath().map { parentPath in
            if path != "" && parentPath != "" {
              return parentPath + "/" + path
            } else if parentPath != "" {
              return parentPath
            } else {
              return path
            }
          }
        default:
          return .failure(.unsupportedFilePathType(sourceTree))
      }
    }
  }
}
