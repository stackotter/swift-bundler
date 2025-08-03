import Foundation
import ErrorKit

extension ConfigurationFlattener {
  typealias Error = RichError<ErrorMessage>

  /// An error message related to ``ConfigurationFlattener``.
  enum ErrorMessage: Throwable {
    case conditionNotMetForProperties(
      OverlayCondition,
      properties: [String]
    )
    case projectBuilderNotASwiftFile(String)
    case reservedProjectName(String)
    case invalidRPMRequirement(String)

    var userFriendlyMessage: String {
      switch self {
        case .conditionNotMetForProperties(let condition, let properties):
          let propertyList = properties.map { "'\($0)'" }.joinedGrammatically(
            singular: "property",
            plural: "properties",
            withTrailingVerb: Verb.be
          )
          return """
            \(propertyList) only available in overlays meeting the condition \
            '\(condition)'
            """
        case .projectBuilderNotASwiftFile(let builder):
          return """
            Library builders must be swift files, and '\(builder)' isn't one
            """
        case .reservedProjectName(let name):
          return "The project name '\(name)' is reserved"
        case .invalidRPMRequirement(let name):
          return "Invalid RPM requirement contains restricted characters: \(name)"
      }
    }
  }
}
