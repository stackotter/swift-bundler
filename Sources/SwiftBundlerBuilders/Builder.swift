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
      guard let input = readLine(strippingNewline: true) else {
        throw BuilderError.noInput
      }

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
