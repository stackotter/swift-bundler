import Foundation
import StackOtterArgParser

/// The subcommand for listing available templates.
struct TemplatesListCommand: Command {
  static var configuration = CommandConfiguration(
    commandName: "list",
    abstract: "List available templates."
  )

  /// The directory to search for templates in.
  @Option(
    name: .long,
    help: "An alternate directory to search for templates in.",
    transform: URL.init(fileURLWithPath:))
  var templateRepository: URL?

  func wrappedRun() throws {
    let templates: [Template]
    if let templateRepository = templateRepository {
      templates = try Templater.enumerateTemplates(in: templateRepository).unwrap()
    } else {
      templates = try Templater.enumerateTemplates().unwrap()
    }

    let repositoryOption: String
    if let templateRepository = templateRepository {
      repositoryOption =
        " --template-repository \(templateRepository.relativePath.quotedIfNecessary)"
    } else {
      repositoryOption = ""
    }

    Output {
      Section("Templates") {
        KeyedList {
          for template in templates {
            KeyedList.Entry(template.name, template.manifest.description)
          }
        }
      }
      Section("Using a template") {
        ExampleCommand("swift bundler create [app-name] --template [template]" + repositoryOption)
      }
    }.show()
  }
}
