import Foundation
import SwiftSyntax
import SwiftParser

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
    guard CommandLine.arguments.count == 3 else {
      print("Usage: gen-schema /path/to/PackageConfiguration.swift /path/to/AppConfiguration.swift")
      Foundation.exit(1)
    }

    let packageConfigSourcePath = CommandLine.arguments[1]
    let appConfigSourcePath = CommandLine.arguments[2]

    guard
      let packageConfigSource = try? readFile(atPath: packageConfigSourcePath),
      let appConfigSource = try? readFile(atPath: appConfigSourcePath)
    else {
      print("Invalid source file path/s")
      Foundation.exit(1)
    }

    let packageConfigStruct = structDecl(
      of: "PackageConfiguration",
      source: packageConfigSource
    )
    let appConfigStruct = structDecl(
      of: "AppConfiguration",
      source: appConfigSource
    )

    var schema = partialSchema(
      for: packageConfigStruct,
      customTypes: ["AppConfiguration": appConfigStruct]
    )

    schema["$schema"] = "https://json-schema.org/draft/2020-12/schema"
    schema["title"] = "Bundler.toml"
    schema["description"] = "A Swift Bundler configuration file"

    let json = try! JSONSerialization.data(withJSONObject: schema, options: .prettyPrinted)
    let jsonString = String(data: json, encoding: .utf8)!

    print(jsonString)
  }

  static func structDecl(of identifier: String, source: String) -> StructDeclSyntax {
    let sourceFile = Parser.parse(source: source)

    for statement in sourceFile.statements {
      for child in statement.children(viewMode: .all) {
        guard
          let decl = child.asProtocol(DeclSyntaxProtocol.self),
          let structDecl = decl as? StructDeclSyntax,
          structDecl.identifier.text == identifier
        else {
          continue
        }

        return structDecl
      }
    }

    print("Missing PackageConfiguration struct")
    Foundation.exit(1)
  }

  static func partialSchema(
    for structDecl: StructDeclSyntax,
    customTypes: [String: StructDeclSyntax]
  ) -> [String: Any] {
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

      propertySchemas[identifier] = property

      if type.last != "?" {
        required.append(identifier)
      }
    }

    schema["properties"] = propertySchemas
    schema["required"] = required

    return schema
  }

  static func partialSchema(
    for type: String,
    customTypes: [String: StructDeclSyntax]
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

        // TODO: Implement schema generation for PlistValue
        if valueType == "PlistValue" {
          return [:]
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
}
