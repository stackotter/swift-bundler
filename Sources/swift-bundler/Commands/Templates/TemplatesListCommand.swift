import Foundation
import ArgumentParser

/// The subcommand for listing available templates.
struct TemplatesListCommand: ParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "list",
    abstract: "List available templates.")
  
  /// The directory to search for templates in.
  @Option(
    name: .long,
    help: "An alternate directory to search for templates in.",
    transform: URL.init(fileURLWithPath:))
  var templateRepository: URL?
  
  func run() throws {
    let templates: [Template]
    if let templateRepository = templateRepository {
      templates = try Templater.enumerateTemplates(in: templateRepository).unwrap()
    } else {
      templates = try Templater.enumerateTemplates().unwrap()
    }
    
    let repositoryOption: String
    if let templateRepository = templateRepository {
      repositoryOption = " --template-repository \(templateRepository.relativePath.quotedIfNecessary)"
    } else {
      repositoryOption = ""
    }
    
    print(Sections {
      Section("Templates") {
        OutputDictionary {
          for template in templates {
            OutputDictionary.Entry(template.name, template.manifest.description)
          }
        }
      }
      Section("Getting more details") {
        ExampleCommand("swift bundler templates info [template]" + repositoryOption)
      }
      Section("Using a template") {
        ExampleCommand("swift bundler create [app-name] --template [template]" + repositoryOption)
      }
    })
  }
}
