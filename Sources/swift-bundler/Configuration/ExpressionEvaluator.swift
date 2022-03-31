import Foundation
import Parsing

/// Evaluates strings that can contain any number of variable substitutions of the form `{VARIABLE_NAME}`.
///
/// In `swift-bundler`, expressions can be entered in certain configuration fields to allow app configuration to access
/// environment values such as the repository's git commit hash.
///
/// An evaluator caches all evaluated variable values to make repeated accesses faster.
struct ExpressionEvaluator {
  /// The parser used to parse expressions. See ``evaluateExpression(_:)``.
  static let expressionParser = Parse {
    Prefix { $0 != "{" }
    OneOf {
      Parse(Optional.some(_:)) {
        "{"
        Prefix { $0 != "}" }
        "}"
      }

      Parse(Substring?.none) {
        End()
      }
    }
  }

  /// The context that expressions are evaluated within.
  var context: Context
  /// A cache holding the most recently computed value for each variable that has been evaluated.
  var cache: [String: String] = [:]

  /// The contextual information required to evaluate value expressions. See ``evaluateExpression(_:)``.
  struct Context {
    /// The root directory of the package.
    var packageDirectory: URL
    /// The app's version.
    var version: String
  }

  /// Creates a new evaluator.
  /// - Parameter context: The context to evaluate expressions within.
  init(context: Context) {
    self.context = context
  }

  /// Evaluates the value of a value expression. See ``ExpressionEvaluator``.
  ///
  /// For the list of valid variables, see ``evaluateExpressionVariable(_:)``.
  /// - Parameters:
  ///   - expression: The expression to evaluate.
  /// - Returns: The string after substituting all variables with their respective values.
  mutating func evaluateExpression(_ expression: String) -> Result<String, ExpressionEvaluatorError> {
    var input = expression[...]
    var output = ""

    while true {
      let variable: Substring?
      do {
        let result = try Self.expressionParser.parse(&input)
        output += result.0
        variable = result.1
      } catch {
        return .failure(.unmatchedBraces(expression, error))
      }

      guard let variable = variable else {
        break
      }

      let result = evaluateVariable(String(variable))
      switch result {
        case let .success(variableValue):
          output += variableValue
        case .failure:
          return result
      }
    }

    return .success(output)
  }

  /// Evaluates the value of a given variable.
  ///
  /// The currently supported variables are:
  /// - `COMMIT_HASH`: Gets the repository's current commit hash
  ///
  /// - Parameters:
  ///   - variable: The name of the variable to evaluate the value of.
  /// - Returns: The value of the variable. If the variable doesn't exist or the evaluator fails to compute the value, a failure is returned.
  mutating func evaluateVariable(_ variable: String) -> Result<String, ExpressionEvaluatorError> {
    if let value = cache[variable] {
      return .success(value)
    }

    let output: String
    switch variable {
      case "COMMIT_HASH":
        let process = Process.create("/usr/bin/git", arguments: ["rev-parse", "HEAD"], directory: context.packageDirectory)
        let result = process.getOutput()

        guard case let .success(string) = result else {
          return .failure(.failedToEvaluateExpressionVariable(message: "Failed to evaluate the 'COMMIT_HASH' variable. Ensure that the package directory is a git repository and that git is installed at `/usr/bin/git`."))
        }

        output = string.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
      case "VERSION":
        output = context.version
      default:
        return .failure(.unknownVariable(variable))
    }

    cache[variable] = output
    return .success(output)
  }
}
