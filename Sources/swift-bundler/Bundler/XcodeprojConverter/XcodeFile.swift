import Foundation
import SwiftXcodeProj

extension XcodeprojConverter {
  /// A file in an Xcode project.
  struct XcodeFile {
    /// The file's path relative to ``base``.
    var relativePath: String
    /// The directory that ``relativePath`` is relative to.
    var base: URL
    /// The file's apparent location in the Xcode file navigator.
    var navigatorPath: String

    /// The file's absolute location.
    var location: URL {
      return base.appendingPathComponent(relativePath)
    }

    /// The file's absolute path.
    var absolutePath: String {
      return location.path
    }

    /// Gets the file's path as it would be in a Swift Bundler project (relative to the
    /// target's sources directory).
    /// - Parameter: The target that the source is in.
    /// - Returns: The file's path as it would be in a Swift Bundler project (relative to
    ///            the target's sources directory).
    func bundlerPath(target: String) -> String {
      var bundlerPath = navigatorPath

      // Simplify th path
      if bundlerPath.hasPrefix(target + "/") {
        // Files are usually under a folder matching the name of the target. To reduce unnecessary
        // nesting, remove this folder from the destination if present.
        bundlerPath.removeFirst(target.count + 1)
      }

      return bundlerPath
    }

    /// Creates a nicer representation of a file in an Xcode project.
    /// - Parameters:
    ///   - file: The file to create a nicer representation of.
    ///   - rootDirectory: The root directory of the Xcode project the file is part of.
    /// - Returns: The nicer representation, or a failure if the file is invalid.
    static func from(
      _ file: PBXFileElement,
      relativeTo rootDirectory: URL
    ) -> Result<XcodeFile, XcodeprojConverterError> {
      let relativePath: String
      do {
        guard let fullPath = try file.fullPath(sourceRoot: "/") else {
          return .failure(.failedToGetRelativePath(file, nil))
        }
        relativePath = String(fullPath.dropFirst())
      } catch {
        return .failure(.failedToGetRelativePath(file, error))
      }

      let navigatorPath = file.name ?? file.path ?? ""

      let simpleCase: () -> Result<XcodeFile, XcodeprojConverterError> = {
        return .success(
          XcodeFile(
            relativePath: relativePath,
            base: rootDirectory,
            navigatorPath: navigatorPath
          ))
      }

      guard let sourceTree = file.sourceTree else {
        return simpleCase()
      }

      switch sourceTree {
        case .absolute:
          let absolute = URL(fileURLWithPath: relativePath)
          return .success(
            XcodeFile(
              relativePath: absolute.lastPathComponent,
              base: absolute.deletingLastPathComponent(),
              navigatorPath: navigatorPath
            ))
        case .sourceRoot:
          return simpleCase()
        case .group:
          guard let parent = file.parent else {
            return simpleCase()
          }

          return XcodeFile.from(parent, relativeTo: rootDirectory).map { parentGroup in
            return XcodeFile(
              relativePath: relativePath,
              base: rootDirectory,
              navigatorPath: combinePaths([parentGroup.navigatorPath, navigatorPath])
            )
          }
        default:
          return .failure(.unsupportedFilePathType(sourceTree))
      }
    }

    /// Combines multiple paths together.
    /// - Parameter paths: The paths to combine into one.
    /// - Returns: The combined path.
    static func combinePaths(_ paths: [String]) -> String {
      return paths.compactMap { path in
        if path.isEmpty {
          return nil
        }

        if path.hasSuffix("/") {
          return String(path.dropLast())
        }

        return path
      }.joined(separator: "/")
    }

    /// Creates a nicer representation of a file in an Xcode project.
    /// - Parameters:
    ///   - file: The file to create a nicer representation of.
    ///   - rootDirectory: The root directory of the Xcode project the file is part of.
    /// - Returns: The nicer representation, or a failure if the file is invalid.
    static func from(
      _ file: PBXBuildFile,
      relativeTo rootDirectory: URL
    ) -> Result<XcodeFile, XcodeprojConverterError> {
      guard let file = file.file else {
        return .failure(.invalidBuildFile(file))
      }

      return XcodeFile.from(file, relativeTo: rootDirectory)
    }
  }
}
