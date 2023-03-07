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

    do {
      let json = try JSONSerialization.data(withJSONObject: schema, options: .prettyPrinted)
      let jsonString = String(data: json, encoding: .utf8)!
      print(jsonString)
    } catch {
      print("Failed to serialize schema")
      Foundation.exit(1)
    }
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
      case .structDecl:
        if let schema = explicitSchema(of: typeDecl) {
          return schema
        }

        let structProperties = properties(of: typeDecl)
          .filter { !$0.modifiers.contains("static") }

        var schema: [String: Any] = [
          "type": "object"
        ]

        var required: [String] = []
        var propertySchemas: [String: Any] = [:]
        for property in structProperties {
          guard let description = property.documentation else {
            print("'\(typeDecl.identifier).\(property.identifier)' missing documentation")
            Foundation.exit(1)
          }

          guard let type = property.type else {
            print("'\(typeDecl.identifier).\(property.identifier)' missing type annotation")
            Foundation.exit(1)
          }

          let tomlIdentifier = camelCaseToLowerSnakeCase(property.identifier)
          var propertySchema = partialSchema(for: type, customTypes: customTypes)
          propertySchema["description"] = description

          propertySchemas[tomlIdentifier] = propertySchema
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
    let value: StringLiteralExprSyntax? = properties(of: typeDecl)
      .filter { (property: PropertyDecl) -> Bool in
        return property.modifiers.contains("static") && property.identifier == "schema"
      }
      .compactMap { (property: PropertyDecl) -> StringLiteralExprSyntax? in
        return property.initialValue?.as(StringLiteralExprSyntax.self)
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
    of typeDecl: TypeDecl
  ) -> [PropertyDecl] {
    var properties: [PropertyDecl] = []
    for child in typeDecl.children {
      guard let memberBlock = child.as(MemberDeclBlockSyntax.self) else {
        continue
      }

      for member in memberBlock.members.children(viewMode: .all) {
        guard let item = member.as(MemberDeclListItemSyntax.self) else {
          continue
        }

        if case let .success(property) = PropertyDecl.parse(from: item) {
          properties.append(property)
        }
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
