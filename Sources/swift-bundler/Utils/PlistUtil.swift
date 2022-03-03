import Foundation
import Parsing

enum PlistError: LocalizedError {
  case unknownPlistEntryType(String)
  case unknownVariable(String)
  case invalidValueExpression(String, Error)
  case failedToEvaluateExpressionVariable(String)
  case serializationFailed(Error)
}

/// A utility for creating the contents of plist files.
enum PlistUtil {
  /// The parser used to parse plist value expressions. See ``evaluateExpression(_:context:)``.
  static let expressionParser = Parse {
    Prefix { $0 != "{" }
    Optionally {
      "{"
      Prefix { $0 != "}" }
      "}"
    }
  }
  
  /// The contextual information required to evaluate plist value expressions. See ``evaluateExpression(_:context:)``.
  struct ExpressionContext {
    var packageDirectory: URL
  }
  
  /// Creates the contents of an app's `Info.plist` file.
  ///
  /// `expressionContext` is required to evaluate the values of the extra plist entries specified in ``AppConfiguration/extraPlistEntries``.
  /// - Parameters:
  ///   - appName: The name of the app.
  ///   - configuration: The app's configuration.
  ///   - expressionContext: The context to evaluate plist expressions within. See ``evaluateExpression(_:context:)``
  /// - Returns: The generated contents for the `Info.plist` file.
  static func createAppInfoPlist(appName: String, configuration: AppConfiguration, expressionContext: ExpressionContext) throws -> Data {
    var entries: [String: Any] = [
      "CFBundleExecutable": appName,
      "CFBundleIconFile": "AppIcon",
      "CFBundleIconName": "AppIcon",
      "CFBundleIdentifier": configuration.bundleIdentifier,
      "CFBundleInfoDictionaryVersion": "6.0",
      "CFBundleName": appName,
      "CFBundlePackageType": "APPL",
      "CFBundleShortVersionString": configuration.version,
      "CFBundleSupportedPlatforms": ["MacOSX"],
      "LSApplicationCategoryType": configuration.category,
      "LSMinimumSystemVersion": configuration.minMacOSVersion,
    ]
    
    for (key, value) in configuration.extraPlistEntries {
      entries[key] = try evaluateExpression(value, context: expressionContext)
    }
    
    return try serialize(entries)
  }
  
  /// Plist value expressions are strings that can contain any number of variable substitutions of the form `{VARIABLE_NAME}`.
  ///
  /// For the list of valid variables, see ``evaluateExpressionVariable(_:)``. This is a concept unique to swift-bundler, it is not a Plist feature.
  /// - Parameters:
  ///   - value: The expression to evaluate.
  ///   - context: The context to evaluate variable values within.
  /// - Returns: The string after substituting all variables with their respective values.
  static func evaluateExpression(_ expression: String, context: ExpressionContext) throws -> String {
    var input = expression[...]
    var output = ""
    do {
      while true {
        let (string, variable) = try expressionParser.parse(&input)
        output += string
        
        guard let variable = variable else {
          break
        }
        
        let variableValue = try evaluateExpressionVariable(String(variable), context: context)
        output += variableValue
      }
    } catch {
      throw PlistError.invalidValueExpression(expression, error)
    }
    return output
  }
  
  /// Evaluates the value of a given variable.
  ///
  /// The currently supported variables are:
  /// - `COMMIT_HASH`: Gets the repository's current commit hash
  ///
  /// - Parameters:
  ///   - variable: The name of the variable to evaluate the value of.
  ///   - context: The context to evaluate the variable within.
  /// - Returns: The value of the variable.
  /// - Throws: If the variable doesn't exist of the evaluator fails to compute the value, an error is thrown.
  static func evaluateExpressionVariable(_ variable: String, context: ExpressionContext) throws -> String {
    switch variable {
      case "COMMIT_HASH":
        do {
          let process = Process.create("/usr/bin/git", arguments: ["rev-parse", "HEAD"], directory: context.packageDirectory)
          let output = try process.getOutput().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
          return output
        } catch {
          throw PlistError.failedToEvaluateExpressionVariable("Failed to evaluate commit hash. Check that the package directory is a git repository and git is installed at `/usr/bin/git`.")
        }
      default:
        throw PlistError.unknownVariable(variable)
    }
  }
  
  static func createBundleInfoPlist(
    bundleIdentifier: String,
    bundleName: String,
    minMacOSVersion: String
  ) throws -> Data {
    let entries: [String: Any] = [
      "CFBundleIdentifier": bundleIdentifier,
      "CFBundleInfoDictionaryVersion": "6.0",
      "CFBundleName": bundleName,
      "CFBundlePackageType": "BNDL",
      "CFBundleSupportedPlatforms": ["MacOSX"],
      "LSMinimumSystemVersion": minMacOSVersion,
    ]
    
    return try serialize(entries)
  }
  
  /// Serializes a plist dictionary into an `xml` format.
  /// - Parameter entries: The dictionary of entries to serialize.
  /// - Returns: The serialized plist file.
  static func serialize(_ entries: [String: Any]) throws -> Data {
    do {
      return try PropertyListSerialization.data(fromPropertyList: entries, format: .xml, options: 0)
    } catch {
      throw PlistError.serializationFailed(error)
    }
  }
}
