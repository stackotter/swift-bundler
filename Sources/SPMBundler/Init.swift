import Foundation
import ArgumentParser

struct Configuration: Codable {
  var bundleIdentifier: String
  var versionString: String
  var buildNumber: Int
  var category: String
  var minOSVersion: String
}

struct Init: ParsableCommand {
  static let configuration = CommandConfiguration(abstract: "Initialise a new Swift executable package and set it up for the bundler.", discussion: "If there is already a package in the directory it just sets up the bundler.")

  @Option(name: .shortAndLong, help: "The directory to initialise the bundler in.", transform: URL.init(fileURLWithPath:))
  var directory: URL

  @Option(name: .customLong("name"), help: "The name for the package. Defaults to the name of the directory. If a swift package already exists in the directory, this is ignored.")
  var packageName: String?

  @Option(name: .long, help: "The bundle identifier for the package (defaults to com.example.[package_name]).")
  var bundleIdentifier: String?

  @Option(name: .shortAndLong, help: "The initial version string (defaults to 0.1.0).")
  var versionString: String?

  @Option(name: .customLong("build"), help: "The initial build number (defaults to 1).")
  var buildNumber: Int?

  @Option(name: .long, help: "The app's category (defaults to public.app-category.games).")
  var category: String?

  @Option(name: .long, help: "The minimum macOS version for the app (defaults to 11.0).")
  var minOSVersion: String?

  func run() throws {
    let packageSwift = directory.appendingPathComponent("Package.swift")
    
    // Initialise the swift package
    if !FileManager.default.itemExists(at: packageSwift, withType: .file) {
      log.info("Initialising swift package (no Package.swift found)")
      var command = "swift package init --type=executable"
      if let name = self.packageName {
        command.append(" --name=\"\(name)\"")
      }
      if Shell.getExitStatus(command, directory, silent: false) != 0 {
        log.critical("Failed to initialise default swift package")
        Foundation.exit(1)
      }
    }

    let packageName = getPackageName(from: directory)

    // Create default configuration
    log.info("Creating configuration")
    let config = Configuration(
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
      log.critical("Failed to create Bundle.json; \(error)")
      Foundation.exit(1)
    }
  }
}