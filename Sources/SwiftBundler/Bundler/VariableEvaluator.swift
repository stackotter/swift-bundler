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
    /// The current date as of the beginning of variable evaluation.
    var date: Date
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
  ) async -> Result<String, VariableEvaluatorError> {
    return await evaluateVariables(in: string, with: .`default`(context))
  }

  /// Evaluates the variables present in a string.
  /// - Parameters:
  ///   - string: The string to evaluate variables in.
  ///   - evaluator: The evaluator to use when evaluating each variable.
  ///   - openingDelimiter: The opening delimiter for a variable. Defaults to `$(`.
  ///   - closingDelimiter: The closing delimiter for a variable. Defaults to `)`.
  /// - Returns: The evaluated string, or a failure if an error occurs.
  static func evaluateVariables(
    in string: String,
    with evaluator: Evaluator,
    openingDelimiter: String = "$(",
    closingDelimiter: String = ")"
  ) async -> Result<String, VariableEvaluatorError> {
    var input = string[...]
    var output = ""

    // Create parser from delimiters
    let parser = Parse {
      OneOf {
        PrefixUpTo(openingDelimiter).map(String.init)
        Rest<Substring>().map(String.init)
        End<Substring>().map { _ in
          ""
        }
      }
      OneOf {
        Parse(Optional.some(_:)) {
          openingDelimiter
          PrefixUpTo(closingDelimiter).map(String.init)
          closingDelimiter
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
      switch await evaluateVariable(variable, with: evaluator) {
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
  ) async -> Result<String, VariableEvaluatorError> {
    switch evaluator {
      case .custom(let evaluator):
        return evaluator(variable).mapError { error in
          return .customEvaluatorFailedToEvaluateVariable(variable, error)
        }
      case .`default`(let context):
        return await evaluateVariable(variable, with: context)
    }
  }

  /// The default variable value evaluator.
  /// - Parameters:
  ///   - variable: The variable to evaluate.
  ///   - context: The context required to evaluate variables.
  /// - Returns: The variable's value, or a failure if an error occurs.
  static func evaluateVariable(  // swiftlint:disable:this cyclomatic_complexity
    _ variable: String,
    with context: Context
  ) async -> Result<String, VariableEvaluatorError> {
    // TODO: Make text macros more generic
    let rfc1034Characters = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890")
    let productRFC1034Identifier = String(
      context.productName.map { character in
        return rfc1034Characters.contains(character) ? character : "-"
      }
    )

    let value: String?
    switch variable {
      case "COMMIT_HASH":
        guard let packageDirectory = context.packageDirectory else {
          return .failure(.packageDirectoryRequiredToEvaluateCommitHash)
        }

        // TODO: Consider using git library
        let result = await Process.create(
          "git",
          arguments: ["rev-parse", "HEAD"],
          directory: packageDirectory
        ).getOutput()

        guard case let .success(string) = result else {
          return .failure(.failedToEvaluateCommitHash(directory: packageDirectory))
        }

        value = string.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
      case "REVISION_NUMBER":
        guard let packageDirectory = context.packageDirectory else {
          return .failure(.packageDirectoryRequiredToEvaluateRevisionNumber)
        }

        // TODO: Consider using a git library
        let result = await Process.create(
          "git",
          arguments: ["rev-list", "--count", "HEAD"],
          directory: packageDirectory
        ).getOutput(excludeStdError: true)

        guard case let .success(string) = result else {
          return .failure(.failedToEvaluateRevisionNumber(directory: packageDirectory))
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
        value = "."  // Swift Bundler avoids using absolute paths
      case "UNIX_TIMESTAMP":
        value = String(context.date.timeIntervalSince1970)
      default:
        value = nil
    }

    guard let value = value else {
      return .failure(.unknownVariable(variable))
    }

    return .success(value)
  }

  /// Evaluates the expressions present in tree-like structure (only string
  /// values within the tree are evaluated).
  /// - Parameters:
  ///   - value: The value to evaluate.
  ///   - context: The context required to evaluate variables.
  /// - Returns: The evaluated value, or a failure if evaluation fails.
  static func evaluateVariables<Tree: VariableEvaluatable>(
    in value: Tree,
    with context: Context
  ) async -> Result<Tree, VariableEvaluatorError> {
    if let stringValue = value.stringValue {
      return await evaluateVariables(in: stringValue, with: context)
        .map(Tree.string(_:))
    } else if let arrayValue = value.arrayValue {
      return await evaluateVariables(in: arrayValue, with: context)
        .map(Tree.array(_:))
    } else if let dictionaryValue = value.dictionaryValue {
      return await evaluateVariables(in: dictionaryValue, with: context)
        .map(Tree.dictionary(_:))
    } else {
      return .success(value)
    }
  }

  /// Evaluates the variables present in an array of tree-like structures (only
  /// string values within the tree-like structures are evaluated).
  /// - Parameters:
  ///   - array: The array to evaluate.
  ///   - context: The context required to evaluate variables.
  /// - Returns: The evaluated array, or a failure if evaluation fails.
  static func evaluateVariables<Tree: VariableEvaluatable>(
    in array: [Tree],
    with context: Context
  ) async -> Result<[Tree], VariableEvaluatorError> {
    var evaluatedArray: [Tree] = []
    for value in array {
      switch await evaluateVariables(in: value, with: context) {
        case .success(let evaluatedValue):
          evaluatedArray.append(evaluatedValue)
        case .failure(let error):
          return .failure(error)
      }
    }
    return .success(evaluatedArray)
  }

  /// Evaluates the variables present in a map containing tree-like structures
  /// (only string values within the tree-like structures are evaluated).
  /// - Parameters:
  ///   - value: The dictionary to evaluate.
  ///   - context: The context required to evaluate variables.
  /// - Returns: The evaluated dictionary, or a failure if evaluation fails.
  static func evaluateVariables<Tree: VariableEvaluatable>(
    in dictionary: [String: Tree],
    with context: Context
  ) async -> Result<[String: Tree], VariableEvaluatorError> {
    var evaluatedDictionary: [String: Tree] = [:]
    for (key, value) in dictionary {
      switch await evaluateVariables(in: value, with: context) {
        case .success(let evaluatedValue):
          evaluatedDictionary[key] = evaluatedValue
        case .failure(let error):
          return .failure(error)
      }
    }
    return .success(evaluatedDictionary)
  }

  /// Evaluates the variables present in supported sections of an app
  /// configuration overlay.
  ///
  /// The only currently supported sections are ``AppConfiguration.Overlay/plist``
  /// and ``AppConfiguration.Overlay/metadata``.
  /// - Parameters:
  ///   - overlay: The configuration overlay to evaluate expressions in.
  ///   - context: The context required to evaluate variables.
  /// - Returns: The evaluated configuration overlay, or a failure if
  ///   evaluation fails.
  static func evaluateVariables(
    in overlay: AppConfiguration.Overlay,
    with context: Context
  ) async -> Result<AppConfiguration.Overlay, VariableEvaluatorError> {
    return await Result.success(overlay)
      .andThen(ifLet: \AppConfiguration.Overlay.plist) { overlay, plist in
        await evaluateVariables(in: plist, with: context).map { plist in
          with(overlay, set(\.plist, plist))
        }
      }
      .andThen(ifLet: \AppConfiguration.Overlay.metadata) { overlay, metadata in
        await evaluateVariables(in: metadata, with: context).map { metadata in
          with(overlay, set(\.metadata, metadata))
        }
      }
  }

  /// Evaluates the variables present in supported sections of an app's configuration.
  ///
  /// The only currently supported sections are ``AppConfiguration/plist``
  /// and ``AppConfiguration/metadata`` (and the equivalent sections within the
  /// configuration's overlays).
  /// - Parameters:
  ///   - configuration: The configuration to evaluate expressions in.
  ///   - appName: The app's name.
  ///   - packageDirectory: The package's root directory.
  /// - Returns: The evaluated configuration, or a failure if evaluation fails.
  static func evaluateVariables(
    in configuration: AppConfiguration,
    named appName: String,
    packageDirectory: URL
  ) async -> Result<AppConfiguration, VariableEvaluatorError> {
    let context = Context(
      appName: appName,
      productName: configuration.product,
      date: Date(),
      packageDirectory: packageDirectory,
      version: configuration.version,
      identifier: configuration.identifier
    )

    return await Result.success(configuration)
      .andThen(ifLet: \AppConfiguration.plist) { configuration, plist in
        await evaluateVariables(in: plist, with: context).map { plist in
          with(configuration, set(\.plist, plist))
        }
      }
      .andThen(ifLet: \AppConfiguration.metadata) { configuration, metadata in
        await evaluateVariables(in: metadata, with: context).map { metadata in
          with(configuration, set(\.metadata, metadata))
        }
      }
      .andThen(ifLet: \AppConfiguration.overlays) { configuration, overlays in
        await overlays.tryMap { overlay in
          await evaluateVariables(in: overlay, with: context)
        }.map { overlays in
          with(configuration, set(\.overlays, overlays))
        }
      }
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
  ) async -> Result<PackageConfiguration, VariableEvaluatorError> {
    var evaluatedConfiguration = configuration

    for (name, app) in configuration.apps {
      let result = await evaluateVariables(
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
