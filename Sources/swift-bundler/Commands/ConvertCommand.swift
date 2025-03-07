import Foundation
import StackOtterArgParser
import TOMLKit

/// The command for converting xcodeprojs to Swift Bundler projects.
struct ConvertCommand: Command {
  static var configuration = CommandConfiguration(
    commandName: "convert",
    abstract: "Converts an xcodeproj to a Swift Bundler project."
  )

  @Argument(
    help: "Xcodeproj to convert.",
    transform: URL.init(fileURLWithPath:))
  var xcodeFile: URL

  @Option(
    name: [.customShort("o"), .customLong("out")],
    help: "The output directory.",
    transform: URL.init(fileURLWithPath:))
  var outputDirectory: URL

  @Flag(
    name: [.customLong("dont-warn")],
    help: "Disables the experimental feature warning")
  var dontWarn = false

  func wrappedRun() async throws {
    // - [x] Convert executable targets
    // - [x] Convert library dependency targets
    // - [x] Preserve project structure
    // - [x] Extract version and identifier
    // - [ ] Extract code signing settings
    // - [x] Extract platform deployment versions
    // - [ ] Extract asset catalog compiler settings
    // - [ ] Extract indentation settings
    // - [ ] Handle tests

    #if !SUPPORT_XCODEPROJ
      // Throw an error as early as possible if the host platform isn't supported
      throw XcodeprojConverterError.hostPlatformNotSupported
    #else
      if !dontWarn {
        log.warning(
          "Converting xcodeprojs is currently an experimental feature. Proceed with caution."
        )
        print("[press ENTER to continue]", terminator: "")
        _ = readLine()
      }

      switch xcodeFile.pathExtension {
        case "xcodeproj":
          try await XcodeprojConverter.convertProject(xcodeFile, outputDirectory: outputDirectory)
            .unwrap()
        case "xcworkspace":
          try await XcodeprojConverter.convertWorkspace(xcodeFile, outputDirectory: outputDirectory)
            .unwrap()
        default:
          log.error(
            "Unknown file extension '\(xcodeFile.pathExtension)'. Expected 'xcodeproj' or 'xcworkspace'"
          )
          Foundation.exit(1)
      }
    #endif
  }
}
