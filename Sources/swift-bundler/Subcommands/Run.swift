import ArgumentParser
import Foundation

struct Run: ParsableCommand {
  @Option(name: [.customLong("directory"), .customShort("d")], help: "The directory containing the package to be bundled and run", transform: URL.init(fileURLWithPath:))
  var packageDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

  @Option(name: .shortAndLong, help: "The build configuration to use (debug|release)", transform: { BuildConfiguration.init(rawValue: $0.lowercased()) })
  var configuration: BuildConfiguration?

  @Option(name: .shortAndLong, help: "The directory to output the bundled .app to", transform: URL.init(fileURLWithPath:))
  var outputDir: URL?

  @Flag(name: [.customShort("p"), .customLong("progress")], help: "Display build progress in a window")
  var displayProgress = false

  @Flag(name: [.customShort("u"), .customLong("universal")], help: "Build a universal application (arm and intel)")
  var shouldBuildUniversal = false

  func run() throws {
    // Load configuration
    let config = Configuration.load(packageDir)
    let target = config.target
    let outputDir = outputDir ?? packageDir.appendingPathComponent(".build/bundler")
    let executable = outputDir.appendingPathComponent("\(target).app/Contents/MacOS/\(target)")
    
    if displayProgress {
      runProgressJob({ setMessage, setProgress in
        Bundler.build(
          packageDir: packageDir,
          configuration: configuration,
          outputDir: outputDir,
          shouldBuildUniversal: shouldBuildUniversal,
          updateProgress: { message, progress, shouldLog in
            if shouldLog {
              log.info(message)
            }
            setMessage(message)
            setProgress(progress)
          })
      },
      title: "Build and run",
      maxProgress: 1)
    } else {
      Bundler.build(
        packageDir: packageDir,
        configuration: configuration,
        outputDir: outputDir,
        shouldBuildUniversal: shouldBuildUniversal,
        updateProgress: { message, _, shouldLog in
          if shouldLog {
            log.info(message)
          }
        })
    }

    print() // New line to separate app output from bundler output

    if Shell.getExitStatus(executable.path, silent: false) != 0 {
      terminate("Failed to run bundled app at \(outputDir.appendingPathComponent("\(target).app").path)")
    }
  }
}