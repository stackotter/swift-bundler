import Foundation
import ArgumentParser

struct TemplatesUpdateCommand: ParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "update",
    abstract: "Update the templates to the latest version.")
  
  func run() throws {
    try Templater.updateTemplates().unwrap()
  }
}
