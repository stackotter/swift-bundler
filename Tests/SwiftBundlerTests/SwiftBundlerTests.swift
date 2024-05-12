import XCTest

@testable import swift_bundler

final class SwiftCrossUITests: XCTestCase {
  func testCommandLineParsing() throws {
    let commandLine = CommandLine.lenientParse(
      "./path/to/my\\ command arg1 'arg2 with spaces' \"arg3 with spaces\" arg4\\ with\\ spaces"
    )

    XCTAssertEqual(
      commandLine,
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
}
