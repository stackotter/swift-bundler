import ArgumentParser
import Foundation

struct Run: ParsableCommand {
  @Option(name: [.customLong("directory"), .customShort("d")], help: "The directory containing the package to be bundled and run", transform: URL.init(fileURLWithPath:))
  var packageDir: URL?

  @Option(name: .shortAndLong, help: "The build configuration to use (debug|release)", transform: { BuildConfiguration.init(rawValue: $0.lowercased()) })
  var configuration: BuildConfiguration?

  @Option(name: .shortAndLong, help: "The directory to output the bundled .app to", transform: URL.init(fileURLWithPath:))
  var outputDir: URL?

  @Flag(name: [.customShort("p"), .customLong("progress")], help: "Display build progress in a window")
  var displayProgress = false

  func run() throws {
    let packageDir = self.packageDir ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

    let builder = Build(packageDir: _packageDir, configuration: _configuration, outputDir: _outputDir, displayProgress: displayProgress)
    if displayProgress {
      runProgressJob({ setMessage, setProgress in
        builder.job(setMessage, setProgress)
      },
      title: "Build and run",
      maxProgress: 1)
    } else {
      builder.job({ _ in }, { _ in })
    }

    let packageName = getPackageName(from: packageDir)
    if Shell.getExitStatus("open \(packageDir.path)/.build/bundler/\(packageName).app") != 0 {
      // Sometimes running it a second time fixes a weird glitch that stops it opening
      log.warning("Failed to run bundled app, retrying...")
      if Shell.getExitStatus("open \(packageDir.path)/.build/bundler/\(packageName).app") != 0 {
        terminate("Failed to run bundled app at \(packageDir.path)/.build/bundler/\(packageName).app")
      } 
    }
  }
}