import Foundation
import ArgumentParser
import TOMLKit
import SwiftXcodeProj

/// The command for converting xcodeprojs to Swift Bundler projects.
struct ConvertCommand: Command {
  static var configuration = CommandConfiguration(
    commandName: "convert",
    abstract: "Converts an xcodeproj to a Swift Bundler project."
  )

  @Argument(
    help: "Xcodeproj to convert.",
    transform: URL.init(fileURLWithPath:))
  var xcodeProjectFile: URL

  @Option(
    name: [.customShort("o"), .customLong("out")],
    help: "The output directory.",
    transform: URL.init(fileURLWithPath:))
  var outputDirectory: URL

  func wrappedRun() throws {
    // - [x] Convert executable targets
    // - [ ] Convert library dependency targets
    // - [x] Preserve project structure
    // - [x] Extract version and identifier
    // - [ ] Extract code signing settings
    // - [ ] Extract platform deployment versions
    // - [ ] Extract asset catalog compiler settings
    // - [ ] Extract indentation settings
    // - [ ] Handle tests

    log.warning("Converting xcodeprojs is currently an experimental feature. Proceed with caution.")
    print("[press ENTER to continue]", terminator: "")
    _ = readLine()

    try XcodeprojConverter.convert(xcodeProjectFile, outputDirectory: outputDirectory).unwrap()
  }
}
