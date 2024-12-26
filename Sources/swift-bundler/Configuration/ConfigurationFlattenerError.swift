import Foundation

/// An error returned by ``ConfigurationFlattener``.
extension ConfigurationFlattener {
  enum Error: LocalizedError {
    case conditionNotMetForProperties(
      AppConfiguration.Overlay.Condition,
      properties: [String]
    )
    case projectBuilderNotASwiftFile(String)
    case localBuilderAPIMustNotSpecifyRevision(_ path: String)
    case gitBasedBuilderAPIMissingAPIRequirement(_ url: URL)
    case defaultBuilderAPIMissingAPIRequirement

    var errorDescription: String? {
      switch self {
        case .conditionNotMetForProperties(let condition, let properties):
          let propertyList = properties.map { "'\($0)'" }.joinedGrammatically(
            singular: "property",
            plural: "properties",
            withTrailingVerb: .be
          )
          return "\(propertyList) only available in overlays meeting the condition '\(condition)'"
        case .projectBuilderNotASwiftFile(let builder):
          return """
            Library builders must be swift files, and '\(builder)' isn't one.
            """
        case .localBuilderAPIMustNotSpecifyRevision(let path):
          return "'api' field is redundant when local builder API is used ('local(\(path))')"
        case .gitBasedBuilderAPIMissingAPIRequirement:
          return "Builder API sourced from git missing API requirement (provide the 'api' field)"
        case .defaultBuilderAPIMissingAPIRequirement:
          return "Deafult Builder API missing API requirement (provide the 'api' field)"
      }
    }
  }
}
