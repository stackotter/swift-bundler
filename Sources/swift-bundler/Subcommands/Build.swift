import Foundation
import ArgumentParser

struct Build: ParsableCommand {
  @Option(name: [.customLong("directory"), .customShort("d")], help: "The directory containing the package to be bundled", transform: URL.init(fileURLWithPath:))
  var packageDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

  @Option(name: .shortAndLong, help: "The build configuration to use (debug|release)", transform: { BuildConfiguration.init(rawValue: $0.lowercased()) })
  var configuration: BuildConfiguration?

  @Option(name: .shortAndLong, help: "The directory to output the bundled .app to", transform: URL.init(fileURLWithPath:))
  var outputDir: URL?

  @Flag(name: [.customShort("p"), .customLong("progress")], help: "Display progress in a window")
  var displayProgress = false

  @Flag(name: [.customShort("u"), .customLong("universal")], help: "Build a universal application (arm and intel)")
  var shouldBuildUniversal = false

  func run() throws {
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
      title: "Build",
      maxProgress: 1)
    } else {
      Bundler.build(
        packageDir: packageDir,
        configuration: configuration,
        outputDir: outputDir,
        shouldBuildUniversal: shouldBuildUniversal)
    }
  }
}

extension Bundler {
  static func build(
    packageDir: URL,
    configuration: BuildConfiguration?,
    outputDir: URL?,
    shouldBuildUniversal: Bool,
    updateProgress updateProgressClosure: (@escaping (_ message: String, _ progress: Double, _ shouldLog: Bool) -> Void) = { _, _, _ in }
  ) {
    var progressFraction: Double = 0
    func updateProgress(_ message: String, _ progress: Double, shouldLog: Bool = true) {
      progressFraction = progress
      updateProgressClosure(message, progress, shouldLog)  
    }

    let configuration = configuration ?? .debug
    let outputDir = outputDir ?? packageDir.appendingPathComponent(".build/bundler")
    let packageName = getPackageName(from: packageDir)
    
    // Run prebuild script if it exists
    updateProgress("Running prebuild script", 0.02)
    runPrebuild(packageDir)

    updateProgress("Loading configuration", 0.05)
    let config: Configuration
    do {
      let data = try Data(contentsOf: packageDir.appendingPathComponent("Bundle.json"))
      config = try JSONDecoder().decode(Configuration.self, from: data)
    } catch {
      terminate("Failed to load config from Bundle.json; \(error)")
    }

    // Build package
    updateProgress("Starting \(configuration.rawValue) build...", 0.1)
    var command = "swift build -c \(configuration.rawValue)"
    if shouldBuildUniversal {
      command += " --arch arm64 --arch x86_64"
    }
    let exitStatus = Shell.getExitStatus(command, packageDir, silent: false, lineHandler: { line in
      if shouldBuildUniversal && line.split(separator: ":")[0].last == "%" {
        // The output style changes completely in universal builds for whatever reason :)
        if let percentage = Double(line.split(separator: ":")[0].dropLast()) {
          updateProgress(line, 0.8 * (percentage / 100) + 0.1, shouldLog: false)
        }
      } else if line.starts(with: "[") {
        let parts = line.split(separator: "]")
        let progressParts = parts[0].dropFirst().split(separator: "/")
        let progress = Double(progressParts[0])!
        let total = Double(progressParts[1])!
        let decimalProgress = progress / total
        updateProgress(line, 0.8 * decimalProgress + 0.1, shouldLog: false)
      } else if line.starts(with: "Fetching") || line.starts(with: "Resolving") || line.starts(with: "Cloning") {
        updateProgress(line, progressFraction, shouldLog: false)
      }
    })
    if exitStatus != 0 {
      terminate("Build failed")
    }

    // Turn the built executable into a .app
    updateProgress("Bundling", 0.9)
    let buildDirSymlink: URL
    if shouldBuildUniversal {
      buildDirSymlink = packageDir.appendingPathComponent(".build/apple/Products/\(configuration.rawValue.capitalized)")
    } else {
      buildDirSymlink = packageDir.appendingPathComponent(".build/\(configuration.rawValue)")
    }
    let buildDir = buildDirSymlink.resolvingSymlinksInPath()
    Bundler.bundle(
      packageDir: packageDir,
      packageName: packageName,
      productsDir: buildDir,
      outputDir: outputDir,
      config: config,
      fixBundles: !shouldBuildUniversal,
      updateProgress: { message, progress, shouldLog in
        let adjustedProgress = 0.9 + progress * 0.07
        updateProgressClosure(message, adjustedProgress, shouldLog)
      })

    // Run postbuild script if it exists
    updateProgress("Running postbuild script", 0.97)
    Bundler.runPostbuild(packageDir)

    updateProgress("Build completed", 1)
  }
}