import Testing
import Foundation

@testable import SwiftBundler

@Test func testCommandLineParsing() throws {
  let commandLine = CommandLine.lenientParse(
    "./path/to/my\\ command arg1 'arg2 with spaces' \"arg3 with spaces\" arg4\\ with\\ spaces"
  )

  #expect(
    commandLine
    ==
    CommandLine(
      command: "./path/to/my command",
      arguments: [
        "arg1",
        "arg2 with spaces",
        "arg3 with spaces",
        "arg4 with spaces",
      ]
    )
  )
}

@Test func testCreationWorkflow() async throws {
  let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent("HelloWorld")

  if directory.exists() {
    try FileManager.default.removeItem(at: directory)
  }

  var creationArguments = ["create", "HelloWorld", "-d", directory.path]

  #if os(macOS)
    // Without this, the build will fail due to a missing minimum deployment version.
    creationArguments += ["-t", "SwiftUI"]
  #endif

  // Ensure creation succeeds
  await SwiftBundler.main(creationArguments)

  // Ensure fresh project builds
  await SwiftBundler.main(["bundle", "HelloWorld", "-d", directory.path, "-o", directory.path])

  // Ensure idempotence
  await SwiftBundler.main(["bundle", "HelloWorld", "-d", directory.path, "-o", directory.path])
}
