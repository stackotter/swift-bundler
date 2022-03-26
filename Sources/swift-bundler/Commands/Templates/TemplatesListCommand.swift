import Foundation
import ArgumentParser

struct TemplatesListCommand: ParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "list",
    abstract: "Lists available templates")
  
  func run() throws {
    let templates = try Templater.enumerateTemplates().unwrap()
    
    for template in templates {
      print("* \(template.name): \(template.manifest.description)")
    }
  }
}
