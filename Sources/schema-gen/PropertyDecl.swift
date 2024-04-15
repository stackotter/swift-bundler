import Foundation
import SwiftSyntax

enum PropertyDeclError: LocalizedError {
  case notVariable
  case notIdentifierBinding
}

/// A declaration of a property belonging to a specific type.
struct PropertyDecl {
  /// The content of the documentation comment if any.
  var documentation: String?
  /// Modifiers such as `static`, `private`, etc.
  var modifiers: [String]
  /// The property's identifier.
  var identifier: String
  /// A type annotation if present.
  var type: String?
  /// An initial value if any.
  var initialValue: Syntax?

  private struct ParsedBinding {
    var patternBinding: PatternBindingSyntax
    var identifier: String
    var type: String?
  }

  /// ``identifier`` converted to lower snake case. Assumes that ``identifier`` is in camel case (as
  /// is convention in Swift).
  var snakeCaseIdentifier: String {
    var words: [String] = []
    var currentWord = ""
    for character in identifier {
      if (character.isUppercase || character.isNumber) && !currentWord.isEmpty {
        words.append(currentWord)
        currentWord = ""
      }

      currentWord += character.lowercased()
    }

    if !currentWord.isEmpty {
      words.append(currentWord)
    }

    return words.joined(separator: "_")
  }

  /// Converts a `MemberBlockItemSyntax` (the most useless thing in existence) into a
  /// ``PropertyDecl`` (much better).
  /// - Parameter decl: A declaration to convert.
  /// - Returns: A success if the declaration was a property, and a failure otherwise.
  static func parse(from decl: MemberBlockItemSyntax) -> Result<PropertyDecl, PropertyDeclError> {
    guard let variable = decl.decl.as(VariableDeclSyntax.self) else {
      return .failure(.notVariable)
    }

    var documentation: String?
    let leadingTrivia = variable.leadingTrivia
    guard leadingTrivia.count >= 3 else {
      return .failure(.notIdentifierBinding)
    }

    var lines: [String] = []
    for trivia in leadingTrivia {
      let triviaString = String(describing: trivia)
        .trimmingCharacters(in: .whitespaces)

      if triviaString.hasPrefix("/// ") {
        lines.append(String(triviaString.dropFirst(4)))
      } else if triviaString == "///" {
        lines.append("")
      }
    }

    if !lines.isEmpty {
      documentation = lines.joined(separator: "\n")
    }

    var modifiers: [String] = []
    let modifierList = variable.modifiers
    for modifier in modifierList {
      modifiers.append(modifier.name.text)
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

  /// Parses a pattern binding list to extract the identifier, type annotation and pattern binding.
  /// - Parameter bindings: A pattern binding list to parse.
  /// - Returns: The parsed binding if it was of a supported format (i.e. identifier pattern
  ///   binding).
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
        type: binding.typeAnnotation?.type.trimmedDescription
      )
    }

    return nil
  }
}
