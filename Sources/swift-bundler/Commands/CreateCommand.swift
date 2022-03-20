import Foundation
import ArgumentParser

struct CreateCommand: ParsableCommand {
  static var configuration = CommandConfiguration(commandName: "create")
  
  @Argument(
    help: "The name of the app to create.")
  var appName: String
  
  @Option(
    name: [.customShort("d"), .customLong("directory")],
    help: "The directory to create the app in. Defaults to creating a new directory matching the name of the app and creating it in there.",
    transform: URL.init(fileURLWithPath:))
  var packageDirectory: URL?
  
  func run() throws {
    guard Self.isValidAppName(appName) else {
      log.error("Invalid app name: app names must only include uppercase and lowercase characters from the English alphabet.")
      return
    }
    
    let defaultPackageDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(appName)
    let packageDirectory = packageDirectory ?? defaultPackageDirectory
    
    try SwiftPackageManager.createPackage(in: packageDirectory, name: appName).unwrap()
  }
  
  /// App names can only contain characters from the English alphabet (to avoid things getting a bit complex when figuring out the product name).
  /// - Parameter name: The name to verify.
  /// - Returns: Whether the app name is valid or not.
  static func isValidAppName(_ name: String) -> Bool {
    let allowedCharacters = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
    let characters = Set(name)
    
    return characters.subtracting(allowedCharacters).isEmpty
  }
}
