import Foundation
import ArgumentParser

struct Postbuild: ParsableCommand {
  @Option(name: [.customLong("directory"), .customShort("d")], help: "The directory of the package to run the postbuild script of", transform: URL.init(fileURLWithPath:))
  var packageDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

  func run() throws {
    Bundler.runPostbuild(packageDir)
  }
}

extension Bundler {
  static func runPostbuild(_ packageDir: URL) {
    let postbuildScript = packageDir.appendingPathComponent("postbuild.sh")
    if FileManager.default.itemExists(at: postbuildScript, withType: .file) {
      if Shell.getExitStatus("sh \(postbuildScript.path)", packageDir, silent: false) != 0 {
        terminate("Failed to run postbuild script")
      }
    }
  }
}