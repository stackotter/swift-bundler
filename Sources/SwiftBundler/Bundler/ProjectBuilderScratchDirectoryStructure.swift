import Foundation

extension ProjectBuilder {
  struct ScratchDirectoryStructure {
    var root: URL
    var sources: URL
    var builder: URL
    var build: URL
    var products: URL
    var builderManifest: URL
    var builderSourceFile: URL

    var requiredDirectories: [URL] {
      [
        root,
        builder,
        build,
        products,
        builderManifest.deletingLastPathComponent(),
        builderSourceFile.deletingLastPathComponent(),
      ]
    }

    init(scratchDirectory: URL) {
      root = scratchDirectory
      sources = scratchDirectory / "sources"
      builder = scratchDirectory / "builder"
      build = scratchDirectory / "build"
      products = scratchDirectory / "products"
      builderManifest = builder / "Package.swift"
      builderSourceFile = builder / "Sources/Builder/Builder.swift"
    }

    func createRequiredDirectories() throws(Error) {
      for directory in requiredDirectories where !directory.exists(withType: .directory) {
        try Error.catch {
          try FileManager.default.createDirectory(at: directory)
        }
      }
    }
  }
}
