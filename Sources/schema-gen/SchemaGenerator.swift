import Foundation
import SwiftParser
import SwiftSyntax

extension FileHandle: Swift.TextOutputStream {
  public func write(_ string: String) {
    let data = Data(string.utf8)
    self.write(data)
  }
}

func printError(_ message: String) {
  var standardError = FileHandle.standardError
  print(message, to: &standardError)
}

@main
struct SchemaGenerator {
  /// A simple conversion from Swift type to JSON type.
  static let jsonTypeConversion: [String: String] = [
    "Int": "integer",
    "Float": "number",
    "Double": "number",
    "String": "string",
  ]

  static func main() {
    guard CommandLine.arguments.count == 2 else {
      printError("Usage: schema-gen /path/to/Sources/swift-bundler/Configuration")
      Foundation.exit(1)
    }

    let sourceDirectory = URL(fileURLWithPath: CommandLine.arguments[1])
    let namespace = Namespace(sourceDirectory: sourceDirectory)

    let packageConfigStruct: TypeDecl
    do {
      packageConfigStruct = try namespace.get("PackageConfiguration")
    } catch {
      printError("\(error)")
      Foundation.exit(1)
    }

    var schema = partialSchema(
      for: packageConfigStruct,
      namespace: namespace
    )

    schema["$schema"] = "https://json-schema.org/draft/2020-12/schema"
    schema["title"] = "Bundler.toml"
    schema["description"] = "A Swift Bundler configuration file"

    do {
      let json = try JSONSerialization.data(
        withJSONObject: schema,
        options: [.prettyPrinted, .sortedKeys]
      )
      let jsonString = String(data: json, encoding: .utf8)!
      print(jsonString)
    } catch {
      printError("Failed to serialize schema")
      Foundation.exit(1)
    }
  }

  /// Generates a partial schema for a Swift Bundler type. Partial schemas exclude
  /// `title`, `description`, etc.
  /// - Properties:
  ///   - typeDecl: The type to generate a schema for.
  ///   - namespace: The namespace to use when generating schemas for properties.
  /// - Returns: A partial schema for the type.
  static func partialSchema(
    for typeDecl: TypeDecl,
    namespace: Namespace
  ) -> [String: Any] {
    switch typeDecl {
      case .enumDecl:
        guard let schema = explicitSchema(of: typeDecl) else {
          printError("Enum '\(typeDecl.identifier)' requires an explicit schema")
          Foundation.exit(1)
        }
        return schema
      case .structDecl:
        if let schema = explicitSchema(of: typeDecl) {
          return schema
        }

        let structProperties = typeDecl.properties
          .filter { !$0.modifiers.contains("static") }

        var schema: [String: Any] = [
          "type": "object"
        ]

        var required: [String] = []
        var propertySchemas: [String: Any] = [:]
        for property in structProperties {
          guard
            let description = property.documentation?.split(separator: "\n").first
          else {
            printError("'\(typeDecl.identifier).\(property.identifier)' missing documentation")
            Foundation.exit(1)
          }

          guard let type = property.type else {
            printError("'\(typeDecl.identifier).\(property.identifier)' missing type annotation")
            Foundation.exit(1)
          }

          var propertySchema = partialSchema(for: type, namespace: namespace)
          propertySchema["description"] = String(description)

          let tomlIdentifier = property.snakeCaseIdentifier
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

  /// Generates a partial schema for an arbitrary type. Partial schemas exclude
  /// `title`, `description`, etc.
  /// - Properties:
  ///   - type: The type's identifier.
  ///   - namespace: The namespace to search in for matching Swift Bundler types
  ///     if the type doesn't have a simple one-to-one mapping to a JSON type.
  /// - Returns: A partial schema for the type.
  static func partialSchema(
    for type: String,
    namespace: Namespace
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
          printError("Dictionary keys must be strings")
          Foundation.exit(1)
        }

        schema["type"] = "object"
        schema["patternProperties"] = [
          "^.*$": partialSchema(
            for: valueType,
            namespace: namespace
          )
        ]
      } else {
        schema["type"] = "array"
        schema["items"] = partialSchema(
          for: strippedType,
          namespace: namespace
        )
      }
    } else {
      do {
        let decl = try namespace.get(type)
        schema = partialSchema(for: decl, namespace: namespace)
      } catch {
        printError("\(error)")
        Foundation.exit(1)
      }
    }

    return schema
  }

  /// Attempts to extract an explicitly defined schema from a type declaration.
  ///
  /// Explicit schemas come in the form of a `static` `schema` property defined
  /// in the declaration with a string literal value. The string literal must
  /// contain no interpolations and must be valid JSON.
  /// - Parameter typeDecl: The type declaration to extract an explicit schema
  ///   from.
  /// - Returns: The result of decoding the explicit schema, or `nil` if the
  ///   type doesn't declare one.
  static func explicitSchema(
    of typeDecl: TypeDecl
  ) -> [String: Any]? {
    let value: StringLiteralExprSyntax? = typeDecl.properties
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
      printError("Failed to decode explicit schema for '\(typeDecl.identifier)'.")
      printError("Ensure that it is a string literal containing valid JSON.")
      Foundation.exit(1)
    }

    return schema
  }
}
