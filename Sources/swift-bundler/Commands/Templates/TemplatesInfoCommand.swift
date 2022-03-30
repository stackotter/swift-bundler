import Foundation
import ArgumentParser
import Rainbow

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
  var templateRepository: URL?

  /// The template to get info about.
  @Argument(
    help: "The template to get info about.")
  var template: String
  
  func run() throws {
    let templates: [Template]
    if let templateRepository = templateRepository {
      templates = try Templater.enumerateTemplates(in: templateRepository).unwrap()
    } else {
      templates = try Templater.enumerateTemplates().unwrap()
    }
    
    guard let template = templates.first(where: { $0.name == self.template }) else {
      log.error("Could not find template '\(self.template)'")
      Foundation.exit(1)
    }
    
    print("Template info\n".bold.underline)
    print("* \("Name".bold): \(template.name)")
    print("* \("Description".bold): \(template.manifest.description)")
    print("* \("Minimum Swift version".bold): \(template.manifest.minimumSwiftVersion)")
    print("* \("Platforms".bold): [\(template.manifest.platforms.joined(separator: ", "))]")
    print("")
    
    var command = "swift bundler create MyApp --template \(template.name)"
    if let templateRepository = templateRepository {
      command += "--template-repository \(templateRepository.relativePath)"
    }
    print("Using this template\n".bold.underline)
    print("$ " + command.cyan)
  }
}
