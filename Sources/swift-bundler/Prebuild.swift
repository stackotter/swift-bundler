import Foundation
import ArgumentParser

struct Prebuild: ParsableCommand {
  @Option(name: [.customLong("directory"), .customShort("d")], help: "The directory of the package to run the prebuild script of", transform: URL.init(fileURLWithPath:))
  var packageDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

  func run() throws {
    Bundler.runPrebuild(packageDir)
  }
}

extension Bundler {
  static func runPrebuild(_ packageDir: URL) {
    let prebuildScript = packageDir.appendingPathComponent("prebuild.sh")
    if FileManager.default.itemExists(at: prebuildScript, withType: .file) {
      if Shell.getExitStatus("sh \(prebuildScript.path)", packageDir, silent: false) != 0 {
        terminate("Failed to run prebuild script")
      }
    }
  }
}