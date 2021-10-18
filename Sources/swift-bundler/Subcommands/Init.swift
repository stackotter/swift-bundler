import Foundation
import ArgumentParser

struct Init: ParsableCommand {
  static let configuration = CommandConfiguration(abstract: "Initialise a new Swift executable package and set it up for the bundler.", discussion: "To add bundler to an existing swift package you currently need to do so manually.")

  @Argument(help: "The name for the package.")
  var packageName: String

  @Option(name: .shortAndLong, help: "The directory to create the package in. Defaults to a new directory with the name provided as package name.", transform: URL.init(fileURLWithPath:))
  var directory: URL?

  @Option(name: .long, help: "The bundle identifier for the package (defaults to com.example.[package_name]).")
  var bundleIdentifier: String?

  @Option(name: .shortAndLong, help: "The initial version string (defaults to 0.1.0).")
  var versionString: String?

  @Option(name: .customLong("build"), help: "The initial build number (defaults to 1).")
  var buildNumber: Int?

  @Option(name: .long, help: "The app's category (defaults to public.app-category.games).")
  var category: String?

  @Option(name: .long, help: "The minimum macOS version for the app (defaults to 11.0, which is Big Sur).")
  var minOSVersion: String?

  func run() throws {
    // Initialise the swift package    
    var packageName = packageName.replacingOccurrences(of: "-", with: "_")
    packageName = packageName.replacingOccurrences(of: " ", with: "_")

    log.info("Using package name '\(packageName)' (spaces and hyphens are not allowed and may have been replaced)")

    let directory = self.directory ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(packageName)
    if !FileManager.default.itemExists(at: directory, withType: .directory) {
      do {
        try FileManager.default.createDirectory(at: directory)
      } catch {
        terminate("Failed to create directory; \(error)")
      }
    }

    log.info("Initialising swift package")
    let command = "swift package init --type=executable --name=\"\(packageName)\""
    if Shell.getExitStatus(command, directory, silent: false) != 0 {
      terminate("Failed to initialise default swift package")
    }

    log.info("Setting minimum macOS version")
    setMinMacOSVersion(directory, packageName)
    log.info("Replacing hello world example")
    replaceHelloWorld(directory, packageName)
    log.info("Replacing .gitignore")
    replaceGitignore(directory)

    // Create default configuration
    log.info("Creating configuration")
    let config = Configuration(
      target: packageName,
      bundleIdentifier: bundleIdentifier ?? "com.example.\(packageName)",
      versionString: versionString ?? "0.1.0",
      buildNumber: buildNumber ?? 1,
      category: category ?? "public.app-category.games",
      minOSVersion: minOSVersion ?? "11.0")
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    do {
      let data = try encoder.encode(config)
      try data.write(to: directory.appendingPathComponent("Bundle.json"))
    } catch {
      terminate("Failed to create Bundle.json; \(error)")
    }
  }

  func replaceGitignore(_ directory: URL) {
    let gitignoreFile = directory.appendingPathComponent(".gitignore")
    do {
      try """
.DS_Store
/.build
/Packages
/*.xcodeproj
xcuserdata/
/.swiftpm
""".write(to: gitignoreFile, atomically: false, encoding: .utf8)
    } catch {
      terminate("Failed to replace contents of '.gitignore'")
    }
  }

  /// Sets the minimum macOS version for the project to 11.0 (the earliest the bundler officially supports).
  func setMinMacOSVersion(_ directory: URL, _ packageName: String) {
    let packageSwiftFile = directory.appendingPathComponent("Package.swift")
    do {
      var contents = try String(contentsOf: packageSwiftFile)
      contents = contents.replacingOccurrences(of: """
let package = Package(
    name: "\(packageName)",
""", with: """
let package = Package(
    name: "\(packageName)",
    platforms: [.macOS(.v11)],
""")
      try contents.write(to: packageSwiftFile, atomically: false, encoding: .utf8)
    } catch {
      terminate("Failed to add minimum macOS version (11.0) to Package.swift")
    }
  }

  /// Replaces default print hello world with a SwiftUI hello world.
  func replaceHelloWorld(_ directory: URL, _ packageName: String) {
    let mainSwift = """
\(packageName)App.main()
"""

    let appSwift = """
import SwiftUI

struct \(packageName)App: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
"""

    let contentViewSwift = """
import SwiftUI

struct ContentView: View {
  var body: some View {
    Text("Hello, World!")
      .padding()
  }
}
"""

    let sourcesDir = directory.appendingPathComponent("Sources/\(packageName)")
    let mainSwiftFile = sourcesDir.appendingPathComponent("main.swift")
    let appSwiftFile = sourcesDir.appendingPathComponent("\(packageName)App.swift")
    let contentViewSwiftFile = sourcesDir.appendingPathComponent("ContentView.swift")

    do {
      try mainSwift.write(to: mainSwiftFile, atomically: false, encoding: .utf8)
      try appSwift.write(to: appSwiftFile, atomically: false, encoding: .utf8)
      try contentViewSwift.write(to: contentViewSwiftFile, atomically: false, encoding: .utf8)
    } catch {
      terminate("Failed to replace default hello world with a SwiftUI hello world; \(error)")
    }
  }
}