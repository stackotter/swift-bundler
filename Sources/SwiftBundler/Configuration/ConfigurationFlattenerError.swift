import Foundation

/// An error returned by ``ConfigurationFlattener``.
extension ConfigurationFlattener {
  enum Error: LocalizedError {
    case conditionNotMetForProperties(
      OverlayCondition,
      properties: [String]
    )
    case projectBuilderNotASwiftFile(String)
    case reservedProjectName(String)
    case other(LocalizedError)

    var errorDescription: String? {
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
        case .other(let error):
          return error.localizedDescription
      }
    }
  }
}
