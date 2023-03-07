import Foundation
import SwiftSyntax

enum PropertyDeclError: LocalizedError {
  case notVariable
  case notIdentifierBinding
}

struct PropertyDecl {
  var documentation: String?
  var modifiers: [String]
  var identifier: String
  var type: String?
  var initialValue: Syntax?

  private struct ParsedBinding {
    var patternBinding: PatternBindingSyntax
    var identifier: String
    var type: String?
  }

  static func parse(from decl: MemberDeclListItemSyntax) -> Result<PropertyDecl, PropertyDeclError> {
    guard let variable = decl.decl.as(VariableDeclSyntax.self) else {
      return .failure(.notVariable)
    }

    var documentation: String?
    if let leadingTrivia = variable.leadingTrivia, leadingTrivia.count >= 3 {
      let trivia = leadingTrivia[leadingTrivia.count - 3]
      let triviaString = String(describing: trivia)
        .trimmingCharacters(in: .whitespaces)

      if triviaString.hasPrefix("/// ") {
        // TODO: Parse multiline doc comments
        let documentationString = triviaString.dropFirst(4).split(separator: "\n").first
        if let documentationString = documentationString {
          documentation = String(documentationString)
        }
      }
    }

    var modifiers: [String] = []
    if let modifierList = variable.modifiers {
      for modifier in modifierList {
        modifiers.append(modifier.name.withoutTrivia().text)
      }
    }

    guard let binding = parseBindings(variable.bindings) else {
      return .failure(.notIdentifierBinding)
    }

    let initialValue = binding.patternBinding
      .children(viewMode: .all).last?
      .children(viewMode: .all).last

    return .success(PropertyDecl(
      documentation: documentation,
      modifiers: modifiers,
      identifier: binding.identifier,
      type: binding.type,
      initialValue: initialValue
    ))
  }

  private static func parseBindings(
    _ bindings: PatternBindingListSyntax
  ) -> ParsedBinding? {
    for binding in bindings.children(viewMode: .all) {
      guard
        let binding = binding.as(PatternBindingSyntax.self),
        let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self)
      else {
        continue
      }

      return ParsedBinding(
        patternBinding: binding,
        identifier: identifierPattern.identifier.text,
        type: binding.typeAnnotation?.type.withoutTrivia().description
      )
    }

    return nil
  }
}
