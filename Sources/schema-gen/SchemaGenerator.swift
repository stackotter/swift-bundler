import Foundation
import SwiftSyntax
import SwiftParser

enum TypeDecl {
  case structDecl(StructDeclSyntax)
  case enumDecl(EnumDeclSyntax)

  var children: SyntaxChildren {
    switch self {
      case .structDecl(let decl):
        return decl.children(viewMode: .all)
      case .enumDecl(let decl):
        return decl.children(viewMode: .all)
    }
  }

  var identifier: String {
    switch self {
      case .structDecl(let decl):
        return decl.identifier.text
      case .enumDecl(let decl):
        return decl.identifier.text
    }
  }
}

@main
struct SchemaGenerator {
  static var jsonTypeConversion: [String: String] = [
    "Int": "integer",
    "Float": "number",
    "Double": "number",
    "String": "string"
  ]

  static func readFile(atPath path: String) throws -> String {
    return try String(contentsOf: URL(fileURLWithPath: path))
  }

  static func main() {
    guard CommandLine.arguments.count == 4 else {
      print("Usage: schema-gen /path/to/PackageConfiguration.swift /path/to/AppConfiguration.swift /path/to/PlistValue.swift")
      Foundation.exit(1)
    }

    let packageConfigSourcePath = CommandLine.arguments[1]
    let appConfigSourcePath = CommandLine.arguments[2]
    let plistValueSourcePath = CommandLine.arguments[3]

    guard
      let packageConfigSource = try? readFile(atPath: packageConfigSourcePath),
      let appConfigSource = try? readFile(atPath: appConfigSourcePath),
      let plistValueSource = try? readFile(atPath: plistValueSourcePath)
    else {
      print("Invalid source file path/s")
      Foundation.exit(1)
    }

    let packageConfigStruct = typeDecl(
      of: "PackageConfiguration",
      source: packageConfigSource
    )
    let appConfigStruct = typeDecl(
      of: "AppConfiguration",
      source: appConfigSource
    )
    let plistValueEnum = typeDecl(
      of: "PlistValue",
      source: plistValueSource
    )

    var schema = partialSchema(
      for: packageConfigStruct,
      customTypes: [
        "AppConfiguration": appConfigStruct,
        "PlistValue": plistValueEnum
      ]
    )

    schema["$schema"] = "https://json-schema.org/draft/2020-12/schema"
    schema["title"] = "Bundler.toml"
    schema["description"] = "A Swift Bundler configuration file"

    let json = try! JSONSerialization.data(withJSONObject: schema, options: .prettyPrinted)
    let jsonString = String(data: json, encoding: .utf8)!

    print(jsonString)
  }

  static func typeDecl(of identifier: String, source: String) -> TypeDecl {
    let sourceFile = Parser.parse(source: source)

    for statement in sourceFile.statements {
      for child in statement.children(viewMode: .all) {
        guard let decl = child.asProtocol(DeclSyntaxProtocol.self) else {
          continue
        }

        if let structDecl = decl as? StructDeclSyntax {
          guard structDecl.identifier.text == identifier else {
            continue
          }
          return .structDecl(structDecl)
        } else if let enumDecl = decl as? EnumDeclSyntax {
          guard enumDecl.identifier.text == identifier else {
            continue
          }
          return .enumDecl(enumDecl)
        }
      }
    }

    print("Missing '\(identifier)' source file")
    Foundation.exit(1)
  }

  static func partialSchema(
    for typeDecl: TypeDecl,
    customTypes: [String: TypeDecl]
  ) -> [String: Any] {
    switch typeDecl {
      case .enumDecl:
        guard let schema = explicitSchema(of: typeDecl) else {
          print("Enum '\(typeDecl.identifier)' requires an explicit schema")
          Foundation.exit(1)
        }
        return schema
      case .structDecl(let structDecl):
        if let schema = explicitSchema(of: typeDecl) {
          return schema
        }

        let structProperties = properties(of: structDecl)

        var schema: [String: Any] = [
          "type": "object"
        ]

        var required: [String] = []
        var propertySchemas: [String: Any] = [:]
        for (identifier, type, description) in structProperties {
          var property = partialSchema(for: type, customTypes: customTypes)

          // TODO: Remove once PlistValue schema generation is implemented
          guard !property.isEmpty else {
            continue
          }

          property["description"] = description

          let tomlIdentifier = camelCaseToLowerSnakeCase(identifier)
          propertySchemas[tomlIdentifier] = property

          if type.last != "?" {
            required.append(tomlIdentifier)
          }
        }

        schema["properties"] = propertySchemas
        schema["required"] = required

        return schema
    }
  }

  static func partialSchema(
    for type: String,
    customTypes: [String: TypeDecl]
  ) -> [String: Any] {
    var cleanedType = type
    if type.last == "?" {
      cleanedType = String(cleanedType.dropLast())
    }

    var schema: [String: Any] = [:]
    if let jsonType = jsonTypeConversion[cleanedType] {
      schema["type"] = jsonType
    } else if cleanedType.first == "[" {
      let strippedType = String(cleanedType.dropFirst().dropLast())
      if strippedType.contains(":") {
        let parts = strippedType.split(separator: ":")
        let keyType = String(parts[0])
        let valueType = String(parts[1]).trimmingCharacters(in: .whitespaces)

        guard keyType == "String" else {
          print("Dictionary keys must be strings")
          Foundation.exit(1)
        }

        schema["type"] = "object"
        schema["patternProperties"] = [
          "^.*$": partialSchema(
            for: valueType,
            customTypes: customTypes
          )
        ]
      } else {
        schema["type"] = "array"
        schema["items"] = partialSchema(
          for: strippedType,
          customTypes: customTypes
        )
      }
    } else if let structDecl = customTypes[type] {
      schema = partialSchema(for: structDecl, customTypes: customTypes)
    } else {
      print("failed to gen schema for '\(type)'")
    }

    return schema
  }

  static func explicitSchema(
    of typeDecl: TypeDecl
  ) -> [String: Any]? {
    let staticModifier = TokenSyntax.staticKeyword().text
    let value: StringLiteralExprSyntax? = typeDecl.children
      .compactMap { $0.as(MemberDeclBlockSyntax.self) }
      .flatMap { (memberDeclBlock: MemberDeclBlockSyntax) -> [VariableDeclSyntax] in
        let children = memberDeclBlock.members.children(viewMode: .all)
        return children.compactMap { (child: Syntax) -> VariableDeclSyntax? in
          child.as(MemberDeclListItemSyntax.self)?.decl.as(VariableDeclSyntax.self)
        }
      }
      .filter { (variable: VariableDeclSyntax) in
        return variable.modifiers?.contains { modifier in
          return modifier.name.withoutTrivia().text == staticModifier
        } ?? false
      }
      .compactMap { (variable: VariableDeclSyntax) -> StringLiteralExprSyntax? in
        return variable.bindings.children(viewMode: .all).compactMap { binding -> StringLiteralExprSyntax? in
          let patternBinding: SyntaxChildren? = binding
            .as(PatternBindingSyntax.self)?
            .children(viewMode: .all)

          guard
            let identifier = patternBinding?
              .first?
              .as(IdentifierPatternSyntax.self)
          else {
            return nil
          }

          let value = patternBinding?.last

          guard identifier.identifier.text == "schema" else {
            return nil
          }

          guard let stringLiteral = value?.children(viewMode: .all).last?.as(StringLiteralExprSyntax.self) else {
            return nil
          }

          return stringLiteral
        }.first
      }
      .first

    guard let stringLiteral = value else {
      return nil
    }

    let schemaJSON = stringLiteral.segments.description
    guard
      let data = schemaJSON.data(using: .utf8),
      let schemaObject = try? JSONSerialization.jsonObject(with: data),
      let schema = schemaObject as? [String: Any]
    else {
      print("Failed to decode explicit schema for '\(typeDecl.identifier)'.")
      print("Ensure that it is a string literal containing valid JSON.")
      Foundation.exit(1)
    }

    return schema
  }

  static func properties(
    of structDecl: StructDeclSyntax
  ) -> [(identifier: String, type: String, description: String?)] {
    var properties: [(String, String, String)] = []
    for child in structDecl.children(viewMode: .all) {
      let node = child.as(SyntaxEnum.self)
      guard case let .memberDeclBlock(memberBlock) = node else {
        continue
      }

      for member in memberBlock.members.children(viewMode: .all) {
        guard case let .memberDeclListItem(item) = member.as(SyntaxEnum.self) else {
          continue
        }

        guard let variable = item.decl.as(VariableDeclSyntax.self) else {
          continue
        }

        let staticModifier = TokenSyntax.staticKeyword().text
        var isStatic = false
        for modifier in variable.modifiers ?? ModifierListSyntax([]) {
          if modifier.name.withoutTrivia().text == staticModifier {
            isStatic = true
            break
          }
        }

        guard !isStatic else {
          continue
        }

        var description: String?
        if let leadingTrivia = variable.leadingTrivia {
          guard leadingTrivia.count >= 3 else {
            print("Missing documentation for '\(variable.withoutTrivia().description)'")
            Foundation.exit(1)
          }

          let trivia = leadingTrivia[leadingTrivia.count - 3]
          let triviaString = String(describing: trivia).trimmingCharacters(in: .whitespaces)
          guard triviaString.hasPrefix("/// ") else {
            print("Missing documentation for '\(variable.withoutTrivia().description)'")
            Foundation.exit(1)
          }

          description = String(triviaString.dropFirst(4))
        }

        guard let description = description else {
          print("Missing documentation for '\(variable.withoutTrivia().description)'")
          Foundation.exit(1)
        }

        var identifier: String?
        var type: String?
        for binding in variable.bindings.children(viewMode: .all) {
          guard
            let binding = binding.as(PatternBindingSyntax.self),
            let identifierSyntax = binding.pattern.as(IdentifierPatternSyntax.self)
          else {
            continue
          }

          identifier = identifierSyntax.identifier.text
          type = binding.typeAnnotation?.type.withoutTrivia().description
          break
        }

        guard let identifier = identifier else {
          continue
        }

        guard let type = type else {
          print("'\(identifier)' is missing a type annotation")
          Foundation.exit(1)
        }

        properties.append((identifier, type, description))
      }
    }

    return properties
  }

  static func camelCaseToLowerSnakeCase(_ camelCase: String) -> String {
    var words: [String] = []
    var currentWord = ""
    for character in camelCase {
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
}
