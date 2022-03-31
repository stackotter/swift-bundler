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
    
    var exampleCommand = "swift bundler create [app-name] --template \(template.name.quotedIfNecessary)"
    if let templateRepository = templateRepository {
      exampleCommand += " --template-repository \(templateRepository.relativePath.quotedIfNecessary)"
    }
    
    print(Sections {
      Section("Template info") {
        OutputDictionary {
          OutputDictionary.Entry("Name", template.name)
          OutputDictionary.Entry("Description", template.manifest.description)
          OutputDictionary.Entry("Minimum Swift version", template.manifest.minimumSwiftVersion)
          OutputDictionary.Entry("Platforms") {
            InlineList(template.manifest.platforms)
          }
        }
      }
      Section("Using this template") {
        ExampleCommand(exampleCommand)
      }
    })
  }
}
