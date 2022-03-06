import Foundation
import Parsing

enum ExpressionEvaluatorError: LocalizedError {
  case unknownVariable(String)
  case invalidValueExpression(String, Error)
  case failedToEvaluateExpressionVariable(String)
}

/// Evaluates strings that can contain any number of variable substitutions of the form `{VARIABLE_NAME}`.
///
/// In `swift-bundler`, expressions can be entered in certain configuration fields to allow app configuration to access
/// environment values such as the repository's git commit hash.
///
/// An evaluator caches all evaluated variable values to make repeated accesses faster.
///
/// It's a class so that caching is more useful when the evaluator is passed around.
class ExpressionEvaluator {
  /// The parser used to parse expressions. See ``evaluateExpression(_:context:)``.
  static let expressionParser = Parse {
    Prefix { $0 != "{" }
    Optionally {
      "{"
      Prefix { $0 != "}" }
      "}"
    }
  }
  
  /// The context that expressions are evaluated within.
  var context: Context
  /// A cache holding the most recently computed value for each variable that has been evaluated.
  var cache: [String: String] = [:]
  
  /// The contextual information required to evaluate value expressions. See ``evaluateExpression(_:context:)``.
  struct Context {
    var packageDirectory: URL
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
  ///   - value: The expression to evaluate.
  /// - Returns: The string after substituting all variables with their respective values.
  func evaluateExpression(_ expression: String) -> Result<String, ExpressionEvaluatorError> {
    var input = expression[...]
    var output = ""
    
    while true {
      let variable: Substring?
      do {
        let result = try Self.expressionParser.parse(&input)
        output += result.0
        variable = result.1
      } catch {
        return .failure(.invalidValueExpression(expression, error))
      }
      
      guard let variable = variable else {
        break
      }
      
      let result = evaluateExpressionVariable(String(variable))
      switch result {
        case let .success(variableValue):
          output += variableValue
        case .failure(_):
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
  /// - Returns: The value of the variable.
  /// - Throws: If the variable doesn't exist or the evaluator fails to compute the value, an error is thrown.
  func evaluateExpressionVariable(_ variable: String) -> Result<String, ExpressionEvaluatorError> {
    if let value = cache[variable] {
      return .success(value)
    }
    
    let output: String
    switch variable {
      case "COMMIT_HASH":
        let process = Process.create("/usr/bin/git", arguments: ["rev-parse", "HEAD"], directory: context.packageDirectory)
        let result = process.getOutput()
        
        guard case let .success(string) = result else {
          return .failure(.failedToEvaluateExpressionVariable("Failed to evaluate commit hash. Check that the package directory is a git repository and git is installed at `/usr/bin/git`."))
        }
        
        output = string.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
      default:
        return .failure(.unknownVariable(variable))
    }
    
    cache[variable] = output
    return .success(output)
  }
}
