import Foundation
import ArgumentParser

struct TemplatesListCommand: ParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "list",
    abstract: "Lists available templates")
  
  @Option(
    name: .long,
    help: "An alternate directory to search for templates in.",
    transform: URL.init(fileURLWithPath:))
  var templatesDirectory: URL?
  
  func run() throws {
    let templates: [Template]
    if let templatesDirectory = templatesDirectory {
      templates = try Templater.enumerateTemplates(in: templatesDirectory).unwrap()
    } else {
      templates = try Templater.enumerateTemplates().unwrap()
    }
    
    for template in templates {
      print("* \(template.name): \(template.manifest.description)")
    }
  }
}
