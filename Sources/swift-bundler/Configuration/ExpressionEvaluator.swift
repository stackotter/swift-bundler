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
          return .failure(
            .failedToEvaluateExpressionVariable(
              message:
                "Failed to evaluate the 'COMMIT_HASH' variable." +
                " Ensure that the package directory is a git repository and that git is installed at `/usr/bin/git`."
            ))
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

  /// Evaluates the expressions present in a plist value (only string values within the tree are evaluated).
  /// - Parameter value: The plist value to evaluate.
  /// - Returns: The evaluated plist value, or a failure if evaluation fails.
  mutating func evaluatePlistValue(_ value: PlistValue) -> Result<PlistValue, ExpressionEvaluatorError> {
    switch value {
      case .string(let string):
        return evaluateExpression(string).map { evaluatedString in
          return .string(evaluatedString)
        }
      case .array(let array):
        return evaluatePlistArray(array).map { evaluatedArray in
          return .array(evaluatedArray)
        }
      case .dictionary(let dictionary):
        return evaluatePlistDictionary(dictionary).map { evaluatedDictionary in
          return .dictionary(evaluatedDictionary)
        }
      default:
        return .success(value)
    }
  }

  /// Evaluates the expressions present in a plist array (only string values are evaluated).
  /// - Parameter array: The plist array to evaluate.
  /// - Returns: The evaluated plist array, or a failure if evaluation fails.
  mutating func evaluatePlistArray(
    _ array: [PlistValue]
  ) -> Result<[PlistValue], ExpressionEvaluatorError> {
    var evaluatedArray: [PlistValue] = []
    for value in array {
      switch evaluatePlistValue(value) {
        case .success(let evaluatedValue):
          evaluatedArray.append(evaluatedValue)
        case .failure(let error):
          return .failure(error)
      }
    }
    return .success(evaluatedArray)
  }

  /// Evaluates the expressions present in a plist dictionary (only string values are evaluated).
  /// - Parameter value: The plist dictionary to evaluate.
  /// - Returns: The evaluated plist dictionary, or a failure if evaluation fails.
  mutating func evaluatePlistDictionary(
    _ dictionary: [String: PlistValue]
  ) -> Result<[String: PlistValue], ExpressionEvaluatorError> {
    var evaluatedDictionary: [String: PlistValue] = [:]
    for (key, value) in dictionary {
      switch evaluatePlistValue(value) {
        case .success(let evaluatedValue):
          evaluatedDictionary[key] = evaluatedValue
        case .failure(let error):
          return .failure(error)
      }
    }
    return .success(evaluatedDictionary)
  }

  /// Evaluates the expressions present in supported sections of an app's configuration.
  ///
  /// The only currently supported section is ``AppConfiguration/plist``.
  /// - Parameter configuration: The configuration to evaluate expressions in.
  /// - Returns: The evaluated configuration, or a failure if evaluation fails.
  mutating func evaluateAppConfiguration(
    _ configuration: AppConfiguration
  ) -> Result<AppConfiguration, ExpressionEvaluatorError> {
    var configuration = configuration

    if let plist = configuration.plist {
      switch evaluatePlistDictionary(plist) {
        case .success(let evaluatedPlist):
          configuration.plist = evaluatedPlist
        case .failure(let error):
          return .failure(error)
      }
    }

    return .success(configuration)
  }

  /// Evaluates the expressions present in supported sections of a package's configuration.
  ///
  /// The only currently supported section in ``AppConfiguration/plist``.
  /// - Parameters:
  ///   - configuration: The configuration to evaluate expressions in.
  ///   - packageDirectory: The package's root directory (used to evaluate certain variables).
  /// - Returns: The evaluated configuratoin, or a failure if evaluation fails.
  static func evaluatePackageConfiguration(
    _ configuration: PackageConfiguration,
    in packageDirectory: URL
  ) -> Result<PackageConfiguration, ExpressionEvaluatorError> {
    var evaluatedConfiguration = configuration

    for (name, app) in configuration.apps {
      var evaluator = ExpressionEvaluator(context: .init(
        packageDirectory: packageDirectory,
        version: app.version
      ))
      switch evaluator.evaluateAppConfiguration(app) {
        case .success(let evaluatedAppConfiguration):
          evaluatedConfiguration.apps[name] = evaluatedAppConfiguration
        case .failure(let error):
          return .failure(error)
      }
    }

    return .success(evaluatedConfiguration)
  }
}
