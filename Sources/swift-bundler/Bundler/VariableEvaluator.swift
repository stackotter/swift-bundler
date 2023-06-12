import Foundation
import Parsing

/// A utility for evaluating strings containing variables of the form `...$(VARIABLE)...`.
enum VariableEvaluator {
  /// The contextual information required to evaluate variables.
  struct Context {
    /// The app's name.
    var appName: String
    /// The app's product name.
    var productName: String
    /// The root directory of the package.
    var packageDirectory: URL?
    /// The app's version.
    var version: String?
    /// The app's identifier.
    var identifier: String?
  }

  /// An evaluator for evaluating the values of variables.
  enum Evaluator {
    case `default`(Context)
    case custom((String) -> Result<String, Error>)
  }

  /// Evaluates the variables present in a string with the default evaluator.
  /// - Parameters:
  ///   - string: The string to evaluate variables in.
  ///   - context: The context required to evaluate variables.
  /// - Returns: The evaluated string, or a failure if an error occurs.
  static func evaluateVariables(
    in string: String,
    with context: Context
  ) -> Result<String, VariableEvaluatorError> {
    return evaluateVariables(in: string, with: .`default`(context))
  }

  /// Evaluates the variables present in a string.
  /// - Parameters:
  ///   - string: The string to evaluate variables in.
  ///   - evaluator: The evaluator to use when evaluating each variable.
  ///   - openingDelimeter: The opening delimeter for a variable. Defaults to `$(`.
  ///   - closingDelimeter: The closing delimeter for a variable. Defaults to `)`.
  /// - Returns: The evaluated string, or a failure if an error occurs.
  static func evaluateVariables(
    in string: String,
    with evaluator: Evaluator,
    openingDelimeter: String = "$(",
    closingDelimeter: String = ")"
  ) -> Result<String, VariableEvaluatorError> {
    var input = string[...]
    var output = ""

    // Create parser from delimeters
    let parser = Parse {
      OneOf {
        PrefixUpTo(openingDelimeter).map(String.init)
        Rest<Substring>().map(String.init)
        End<Substring>().map { _ in
          ""
        }
      }
      OneOf {
        Parse(Optional.some(_:)) {
          openingDelimeter
          PrefixUpTo(closingDelimeter).map(String.init)
          closingDelimeter
        }

        Parse(String?.none) {
          End<Substring>()
        }
      }
    }

    while true {
      // Extract next variable if there is one
      let variable: String?
      do {
        let result = try parser.parse(&input)
        output += result.0
        variable = result.1
      } catch {
        return .failure(.unmatchedBrackets(string, error))
      }

      guard let variable = variable else {
        break
      }

      // Evaluate variable value and append to output
      switch evaluateVariable(variable, with: evaluator) {
        case .success(let value):
          output += value
        case .failure(let error):
          return .failure(error)
      }
    }

    return .success(output)
  }

  /// Evaluates the value of a variable.
  /// - Parameters:
  ///   - variable: The variable to evaluate.
  ///   - evaluator: The evaluator to use.
  /// - Returns: The variable's value, or a failure if an error occurs.
  static func evaluateVariable(
    _ variable: String,
    with evaluator: Evaluator
  ) -> Result<String, VariableEvaluatorError> {
    switch evaluator {
      case .custom(let evaluator):
        return evaluator(variable).mapError { error in
          return .customEvaluatorFailedToEvaluateVariable(variable, error)
        }
      case .`default`(let context):
        return evaluateVariable(variable, with: context)
    }
  }

  /// The default variable value evaluator.
  /// - Parameters:
  ///   - variable: The variable to evaluate.
  ///   - context: The context required to evaluate variables.
  /// - Returns: The variable's value, or a failure if an error occurs.
  static func evaluateVariable( // swiftlint:disable:this cyclomatic_complexity
    _ variable: String,
    with context: Context
  ) -> Result<String, VariableEvaluatorError> {
    // TODO: Make text macros more generic
    let rfc1034Characters = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890")
    let productRFC1034Identifier = String(context.productName.map { character in
      return rfc1034Characters.contains(character) ? character : "-"
    })

    let value: String?
    switch variable {
      case "COMMIT_HASH":
        guard let packageDirectory = context.packageDirectory else {
          return .failure(.packageDirectoryRequiredToEvaluateCommitHash)
        }

        // TODO: Consider using git library
        let result = Process.create(
          "/usr/bin/git",
          arguments: ["rev-parse", "HEAD"],
          directory: packageDirectory
        ).getOutput()

        guard case let .success(string) = result else {
          return .failure(.failedToEvaluateCommitHash(directory: packageDirectory))
        }

        value = string.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
      case "VERSION", "MARKETING_VERSION", "CURRENT_PROJECT_VERSION":
        value = context.version
      case "PRODUCT_BUNDLE_IDENTIFIER":
        value = context.identifier
      case "PRODUCT_NAME":
        value = context.productName
      case "PRODUCT_NAME:rfc1034identifier":
        value = productRFC1034Identifier
      case "PRODUCT_BUNDLE_PACKAGE_TYPE":
        value = "APPL"
      case "DEVELOPMENT_LANGUAGE":
        value = "en"
      case "PRODUCT_MODULE_NAME":
        value = productRFC1034Identifier.replacingOccurrences(of: "-", with: "_")
      case "SRCROOT":
        value = "." // Swift Bundler avoids using absolute paths
      default:
        value = nil
    }

    guard let value = value else {
      return .failure(.unknownVariable(variable))
    }

    return .success(value)
  }

  /// Evaluates the expressions present in a plist value (only string values within the tree are evaluated).
  /// - Parameters:
  ///   - value: The plist value to evaluate.
  ///   - context: The context required to evaluate variables.
  /// - Returns: The evaluated plist value, or a failure if evaluation fails.
  static func evaluateVariables(
    in value: PlistValue,
    with context: Context
  ) -> Result<PlistValue, VariableEvaluatorError> {
    switch value {
      case .string(let string):
        return evaluateVariables(in: string, with: context).map { evaluatedString in
          return .string(evaluatedString)
        }
      case .array(let array):
        return evaluateVariables(in: array, with: context).map { evaluatedArray in
          return .array(evaluatedArray)
        }
      case .dictionary(let dictionary):
        return evaluateVariables(in: dictionary, with: context).map { evaluatedDictionary in
          return .dictionary(evaluatedDictionary)
        }
      default:
        return .success(value)
    }
  }

  /// Evaluates the variables present in a plist array (only string values are evaluated).
  /// - Parameters:
  ///   - array: The plist array to evaluate.
  ///   - context: The context required to evaluate variables.
  /// - Returns: The evaluated plist array, or a failure if evaluation fails.
  static func evaluateVariables(
    in array: [PlistValue],
    with context: Context
  ) -> Result<[PlistValue], VariableEvaluatorError> {
    var evaluatedArray: [PlistValue] = []
    for value in array {
      switch evaluateVariables(in: value, with: context) {
        case .success(let evaluatedValue):
          evaluatedArray.append(evaluatedValue)
        case .failure(let error):
          return .failure(error)
      }
    }
    return .success(evaluatedArray)
  }

  /// Evaluates the variables present in a plist dictionary (only string values are evaluated).
  /// - Parameters:
  ///   - value: The plist dictionary to evaluate.
  ///   - context: The context required to evaluate variables.
  /// - Returns: The evaluated plist dictionary, or a failure if evaluation fails.
  static func evaluateVariables(
    in dictionary: [String: PlistValue],
    with context: Context
  ) -> Result<[String: PlistValue], VariableEvaluatorError> {
    var evaluatedDictionary: [String: PlistValue] = [:]
    for (key, value) in dictionary {
      switch evaluateVariables(in: value, with: context) {
        case .success(let evaluatedValue):
          evaluatedDictionary[key] = evaluatedValue
        case .failure(let error):
          return .failure(error)
      }
    }
    return .success(evaluatedDictionary)
  }

  /// Evaluates the variables present in supported sections of an app's configuration.
  ///
  /// The only currently supported section is ``AppConfiguration/plist``.
  /// - Parameters:
  ///   - configuration: The configuration to evaluate expressions in.
  ///   - appName: The app's name.
  ///   - packageDirectory: The package's root directory.
  /// - Returns: The evaluated configuration, or a failure if evaluation fails.
  static func evaluateVariables(
    in configuration: AppConfiguration,
    named appName: String,
    packageDirectory: URL
  ) -> Result<AppConfiguration, VariableEvaluatorError> {
    var configuration = configuration

    if let plist = configuration.plist {
      let context = Context(
        appName: appName,
        productName: configuration.product,
        packageDirectory: packageDirectory,
        version: configuration.version,
        identifier: configuration.identifier
      )

      switch evaluateVariables(in: plist, with: context) {
        case .success(let evaluatedPlist):
          configuration.plist = evaluatedPlist
        case .failure(let error):
          return .failure(error)
      }
    }

    return .success(configuration)
  }

  /// Evaluates the variables present in supported sections of a package's configuration.
  ///
  /// The only currently supported section in ``AppConfiguration/plist``.
  /// - Parameters:
  ///   - configuration: The configuration to evaluate expressions in.
  ///   - packageDirectory: The package's root directory (used to evaluate certain variables).
  /// - Returns: The evaluated configuration, or a failure if evaluation fails.
  static func evaluateVariables(
    in configuration: PackageConfiguration,
    packageDirectory: URL
  ) -> Result<PackageConfiguration, VariableEvaluatorError> {
    var evaluatedConfiguration = configuration

    for (name, app) in configuration.apps {
      let result = evaluateVariables(
        in: app,
        named: name,
        packageDirectory: packageDirectory
      )

      switch result {
        case .success(let evaluatedAppConfiguration):
          evaluatedConfiguration.apps[name] = evaluatedAppConfiguration
        case .failure(let error):
          return .failure(error)
      }
    }

    return .success(evaluatedConfiguration)
  }
}
