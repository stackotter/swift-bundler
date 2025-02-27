import Foundation

/// A project builder.
public protocol Builder {
  /// Builds the project defined by the given context.
  static func build(_ context: some BuilderContext) async throws -> BuilderResult
}

private enum BuilderError: LocalizedError {
  case noInput

  var errorDescription: String? {
    switch self {
      case .noInput:
        return "No input provided to builder (expected JSON object on stdin)"
    }
  }
}

extension Builder {
  /// Default builder entrypoint. Parses builder context from stdin.
  public static func main() async {
    do {
      print("Reading line...")
      let input = try await readLineAsync(strippingNewline: true)
      print("Done reading line \(input)")

      let context = try JSONDecoder().decode(
        _BuilderContextImpl.self, from: Data(input.utf8)
      )

      _ = try await build(context)
    } catch {
      print(error)
      Foundation.exit(1)
    }
  }
}

func readLineAsync(strippingNewline: Bool) async throws -> String {
    if #available(macOS 12.0, *) {
        for try await line in FileHandle.standardInput.bytes.lines {
            if strippingNewline {
                return line.trimmingCharacters(in: .newlines)
            } else {
                return line
            }
        }

        throw BuilderError.noInput
    } else {
        guard let line = readLine(strippingNewline: strippingNewline) else {
            throw BuilderError.noInput
        }

        return line
    }
}
