import Foundation
import ArgumentParser

/// The subcommand for getting info about a template.
struct TemplatesInfoCommand: ParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "info",
    abstract: "Get info about a template.")
  
  /// The directory to search for templates in.
  @Option(
    name: .long,
    help: "An alternate directory to search for the template in.",
    transform: URL.init(fileURLWithPath:))
  var templatesDirectory: URL?

  /// The template to get info about.
  @Argument(
    help: "The template to get info about.")
  var template: String
  
  func run() throws {
    let templates: [Template]
    if let templatesDirectory = templatesDirectory {
      templates = try Templater.enumerateTemplates(in: templatesDirectory).unwrap()
    } else {
      templates = try Templater.enumerateTemplates().unwrap()
    }
    
    guard let template = templates.first(where: { $0.name == self.template }) else {
      log.error("Could not find template '\(self.template)'")
      Foundation.exit(1)
    }

    print("* '\(template.name)':")
    print("  * \(template.manifest.description)")
    print("  * Minimum Swift version: \(template.manifest.minimumSwiftVersion)")
    print("  * Platforms: [\(template.manifest.platforms.joined(separator: ", "))]")
  }
}
