import Foundation

/// An error returned by ``ConfigurationFlattener``.
enum ConfigurationFlattenerError: LocalizedError {
  case conditionNotMetForProperties(
    AppConfiguration.Overlay.Condition,
    properties: [String]
  )

  var errorDescription: String? {
    switch self {
      case .conditionNotMetForProperties(let condition, let properties):
        let propertyList = properties.map { "'\($0)'" }.joinedGrammatically(
          singular: "property",
          plural: "properties",
          withTrailingVerb: Verb(singular: "only exists", plural: "only exist")
        )
        return "\(propertyList) in overlays meeting the condition '\(condition)'"
    }
  }
}
