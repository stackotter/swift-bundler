import MacroToolkit
import SwiftSyntax
import SwiftSyntaxMacros

public struct ConfigurationMacro {}

struct ConfigurationProperty {
  var property: Property
  var type: String
  var overlayType: String
  var flatType: String
  var flatTypeDefaultValue: ExprSyntax?
  var validation: ClosureExprSyntax?
  var excludeFromOverlay: Bool
  var excludeFromFlat: Bool
  var condition: Expr?
  var key: String

  var identifier: String {
    property.identifier
  }
}

struct AggregateProperty {
  var name: String
  var methodIdentifier: String
  var type: Type
}

extension ConfigurationMacro: ExtensionMacro {
  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    guard let type = Decl(declaration).asStruct else {
      throw MacroError("@Configuration must be attached to a struct")
    }

    guard
      let overlayableParameter = destructureSingle(MacroAttribute(node).arguments),
      overlayableParameter.label == "overlayable",
      let overlayable = overlayableParameter.expr.asBooleanLiteral?.value
    else {
      throw MacroError("usage: @Configuration(overlayable: true)")
    }

    let properties = try extractConfigurationProperties(type)
    let aggregateProperties = try extractAggregateProperties(type)

    return [
      try ExtensionDeclSyntax("extension \(raw: type.identifier): Flattenable") {
        DeclSyntax(try generateFlattenMethod(
          type,
          properties,
          aggregateProperties,
          overlayable: overlayable
        ))
        DeclSyntax(try generateFlatStruct(type, properties, aggregateProperties))
      }
    ]
  }
}

extension ConfigurationMacro: MemberMacro {
  public static func expansion(
    of node: SwiftSyntax.AttributeSyntax,
    providingMembersOf declaration: some SwiftSyntax.DeclSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some SwiftSyntaxMacros.MacroExpansionContext
  ) throws -> [SwiftSyntax.DeclSyntax] {
    guard let type = Decl(declaration).asStruct else {
      throw MacroError("@Configuration must be attached to a struct")
    }

    guard
      let overlayableParameter = destructureSingle(MacroAttribute(node).arguments),
      overlayableParameter.label == "overlayable",
      let overlayable = overlayableParameter.expr.asBooleanLiteral?.value
    else {
      throw MacroError("usage: @Configuration(overlayable: true)")
    }

    let properties = try extractConfigurationProperties(type)

    var members: [DeclSyntax] = [
      DeclSyntax(try EnumDeclSyntax("enum CodingKeys: String, CodingKey") {
        for property in properties where property.condition == nil {
          try EnumCaseDeclSyntax("case \(raw: property.identifier) = \(StringLiteralExprSyntax(content: property.key))")
        }
        if overlayable {
          try EnumCaseDeclSyntax("case overlays")
        }
      })
    ]

    if overlayable {
      members += [
        DeclSyntax(
          try VariableDeclSyntax("var overlays: [Overlay]?").with(
            \.leadingTrivia,
            .docLineComment("/// Conditionally applied configuration overlays.").appending(.newline)
          )
        ),
        DeclSyntax(try generateOverlayStruct(type, properties)),
      ]
    }

    return members
  }
}

extension ConfigurationMacro {
  static func generateFlattenMethod(
    _ type: Struct,
    _ properties: [ConfigurationProperty],
    _ aggregateProperties: [AggregateProperty],
    overlayable: Bool
  ) throws -> FunctionDeclSyntax {
    let properties = properties.filter { property in
      !property.excludeFromFlat
    }

    let validations: [(property: String, validation: ClosureExprSyntax)] =
      properties.compactMap { property in
        guard let validation = property.validation else {
          return nil
        }
        return (property: property.identifier, validation: validation)
      }

    return try FunctionDeclSyntax("func flatten(with context: ConfigurationFlattener.Context) throws(ConfigurationFlattener.Error) -> Self.Flat") {
      if overlayable {
        StmtSyntax(
          """

          let configuration = try ConfigurationFlattener.mergeOverlays(
            overlays ?? [],
            into: self,
            with: context
          )
          """
        )
      } else {
        StmtSyntax(
          """

          let configuration = self
          """
        )
      }

      for (property, validation) in validations {
        StmtSyntax("\ntry \(validation)(\(raw: property))")
      }

      ReturnStmtSyntax(
        returnKeyword: .keyword(.return),
        expression: FunctionCallExprSyntax(
          calledExpression: ExprSyntax("Flat"),
          leftParen: .leftParenToken(),
          arguments: LabeledExprListSyntax {
            for property in properties {
              let expression = if let defaultValue = property.flatTypeDefaultValue {
                ExprSyntax("try configuration.\(raw: property.identifier)?.flatten(with: context) ?? \(defaultValue)")
              } else {
                ExprSyntax("try configuration.\(raw: property.identifier).flatten(with: context)")
              }
              LabeledExprSyntax(
                label: property.identifier,
                expression: expression
              )
            }
            for property in aggregateProperties {
              LabeledExprSyntax(
                label: property.name,
                expression: ExprSyntax(
                  "try configuration.\(raw: property.methodIdentifier)(with: context)"
                )
              )
            }
          },
          rightParen: .rightParenToken()
        )
      )
    }
  }

  static func generateFlatStruct(
    _ type: Struct,
    _ properties: [ConfigurationProperty],
    _ aggregateProperties: [AggregateProperty]
  ) throws -> StructDeclSyntax {
    let properties = properties.filter { property in
      !property.excludeFromFlat
    }

    return try StructDeclSyntax("struct Flat") {
      for property in properties {
        try VariableDeclSyntax("var \(raw: property.identifier): \(raw: property.flatType)")
      }
      for property in aggregateProperties {
        try VariableDeclSyntax("var \(raw: property.name): \(property.type._syntax)")
      }
    }.with(
      \.leadingTrivia,
      .docLineComment(
        """
        /// A flattened version of ``\(type.identifier)`` (generally with all \
        applicable overlays applied).
        """
      ).appending(.newline)
    )
  }

  static func generateOverlayStruct(
    _ type: Struct,
    _ properties: [ConfigurationProperty]
  ) throws -> StructDeclSyntax {
    let properties = properties.filter { property in
      !property.excludeFromOverlay
    }

    let exclusivePropertyGroups = collectExclusiveProperties(properties)

    let exclusiveProperties = dictionarySyntax(
      exclusivePropertyGroups.map { condition, properties in
        return (
          condition._syntax,
          ExprSyntax("""
            PropertySet()
              \(raw: properties.map { ".add(.\($0), \\.\($0))" }.joined())
            """)
        )
      }
    )

    return try StructDeclSyntax("struct Overlay: Codable, ConfigurationOverlay") {
      try TypeAliasDeclSyntax("typealias Base = \(raw: type.identifier)")

      DeclSyntax(
        """
        static let exclusiveProperties: [OverlayCondition: PropertySet<Self>] = \(exclusiveProperties)
        """
      )

      try VariableDeclSyntax("var condition: OverlayCondition")

      for property in properties {
        try VariableDeclSyntax("var \(raw: property.identifier): \(raw: property.overlayType)")
      }

      try EnumDeclSyntax("enum CodingKeys: String, CodingKey") {
        try EnumCaseDeclSyntax("case condition")

        for property in properties {
          try EnumCaseDeclSyntax("case \(raw: property.identifier) = \(StringLiteralExprSyntax(content: property.key))")
        }
      }

      try FunctionDeclSyntax("func merge(into base: inout Base)") {
        for property in properties {
          StmtSyntax(
            "Self.merge(&base.\(raw: property.identifier), \(raw: property.identifier))\n"
          )
        }
      }
    }
  }

  static func dictionarySyntax(_ items: [(ExprSyntax, ExprSyntax)]) -> DictionaryExprSyntax {
    let content: DictionaryExprSyntax.Content
    if items.isEmpty {
      content = .colon(.colonToken())
    } else {
      content = .elements(DictionaryElementListSyntax {
        for (key, value) in items {
          DictionaryElementSyntax(key: key, value: value)
        }
      })
    }
    return DictionaryExprSyntax(content: content)
  }

  static func collectExclusiveProperties(
    _ properties: [ConfigurationProperty]
  ) -> [(condition: Expr, properties: [String])] {
    var exclusivePropertyGroups: [(condition: Expr, properties: [String])] = []
    for property in properties {
      guard let condition = property.condition else {
        continue
      }
      if let index = exclusivePropertyGroups.firstIndex(where: { group in
        group.condition._syntax.description == condition._syntax.description
      }) {
        exclusivePropertyGroups[index].properties.append(property.identifier)
      } else {
        exclusivePropertyGroups.append((condition, [property.identifier]))
      }
    }
    return exclusivePropertyGroups
  }

  static func extractConfigurationProperties(_ type: Struct) throws -> [ConfigurationProperty] {
    return try type.properties.filter { property in
      property.isStored && !property.isStatic
    }.map { property in
      guard let type = property.type else {
        throw MacroError("Configuration properties must have explicit type annotations")
      }

      var overlayType = type.description
      let isOptional: Bool
      switch type {
        case .optional, .implicitlyUnwrappedOptional:
          isOptional = true
        case .simple(let simpleType):
          isOptional = simpleType.name == "Optional"
        default:
          isOptional = false
      }
      // TODO: Do this a bit nicer once we can destructure normalized types with MacroToolkit
      if !isOptional {
        overlayType = "Optional<\(overlayType)>"
      }

      let wrappedType: TypeSyntax?
      switch type {
        case .optional(let wrapped):
          wrappedType = wrapped._baseSyntax.wrappedType
        case .implicitlyUnwrappedOptional(let wrapped):
          wrappedType = wrapped._baseSyntax.wrappedType
        case .simple(let simpleType) where simpleType.name == "Optional":
          wrappedType = (simpleType.genericArguments ?? []).first?._baseSyntax
        default:
          wrappedType = nil
      }

      let flatType: String
      let flatTypeDefaultValue: ExprSyntax?
      if let wrappedType {
        switch Type(wrappedType) {
          case .array:
            flatTypeDefaultValue = "[]"
          case .dictionary:
            flatTypeDefaultValue = "[:]"
          case .simple(let simpleType):
            if simpleType.name == "Array" {
              flatTypeDefaultValue = "[]"
            } else if simpleType.name == "Dictionary" {
              flatTypeDefaultValue = "[:]"
            } else {
              flatTypeDefaultValue = nil
            }
          default:
            flatTypeDefaultValue = nil
        }
        if flatTypeDefaultValue == nil {
          flatType = type.description
        } else {
          flatType = wrappedType.description
        }
      } else {
        flatType = type.description
        flatTypeDefaultValue = nil
      }

      var explicitKey: String?
      var condition: Expr?
      var validation: ClosureExprSyntax?
      var excludeFromOverlay = false
      var excludeFromFlat = false
      for attribute in property.attributes {
        guard let attribute = attribute.attribute?.asMacroAttribute else {
          continue
        }

        if attribute.name.description == "ConfigurationKey" {
          guard explicitKey == nil else {
            throw MacroError("Only apply @ConfigurationKey once per property")
          }

          guard
            let argument = destructureSingle(attribute.arguments),
            argument.label == nil,
            let key = argument.expr.asStringLiteral?.value
          else {
            throw MacroError("usage: @ConfigurationKey(\"my_custom_key\")")
          }

          explicitKey = key
        } else if attribute.name.description == "Available" {
          guard condition == nil else {
            throw MacroError("Only apply @Available once per property")
          }

          guard
            let argument = destructureSingle(attribute.arguments),
            argument.label == nil
          else {
            throw MacroError("usage: @Available(.platform(\"linux\"))")
          }

          guard property.initialValue != nil else {
            throw MacroError("Properties marked with @Available must have default values")
          }

          condition = argument.expr
        } else if attribute.name.description == "Validate" {
          guard validation == nil else {
            throw MacroError("Only apply @Validation once per property")
          }

          guard
            let argument = destructureSingle(attribute.arguments),
            argument.label == nil,
            let closure = argument.expr._syntax.as(ClosureExprSyntax.self)
          else {
            throw MacroError("usage: @Validate({ throw ValidationError(\"Not valid!\") })")
          }

          validation = closure
        } else if attribute.name.description == "ExcludeFromOverlay" {
          guard !excludeFromOverlay else {
            throw MacroError("Only apply @ExcludeFromOverlay once per property")
          }

          guard attribute.arguments.isEmpty else {
            throw MacroError("@ExcludeFromOverlay takes no arguments")
          }

          excludeFromOverlay = true
        } else if attribute.name.description == "ExcludeFromFlat" {
          guard !excludeFromFlat else {
            throw MacroError("Only apply @ExcludeFromFlat once per property")
          }

          guard attribute.arguments.isEmpty else {
            throw MacroError("@ExcludeFromFlat takes no arguments")
          }

          excludeFromFlat = true
        }
      }

      return ConfigurationProperty(
        property: property,
        type: type.description,
        overlayType: overlayType,
        flatType: "\(flatType).Flat",
        flatTypeDefaultValue: flatTypeDefaultValue,
        validation: validation,
        excludeFromOverlay: excludeFromOverlay,
        excludeFromFlat: excludeFromFlat,
        condition: condition,
        key: explicitKey ?? lowerCamelCaseToSnakeCase(property.identifier)
      )
    }
  }

  private static func extractAggregateProperties(_ type: Struct) throws -> [AggregateProperty] {
    let methods = type.members.compactMap(\.asFunction)
    return try methods.compactMap { method -> AggregateProperty? in
      var name: String?
      for attribute in method.attributes {
        guard
          let attribute = attribute.attribute?.asMacroAttribute,
          attribute.name.description == "Aggregate"
        else {
          continue
        }

        guard
          let nameProperty = destructureSingle(attribute.arguments),
          nameProperty.label == nil,
          let nameString = nameProperty.expr.asStringLiteral?.value
        else {
          throw MacroError("usage: @Aggregate(\"propertyName\")")
        }

        if name != nil {
          throw MacroError("Only apply @Aggregate once per method")
        }

        name = nameString
      }

      guard let name else {
        return nil
      }

      guard let returnType = method.returnType else {
        throw MacroError("@Aggregate method must have a return type")
      }

      guard
        let errorType = method._syntax.signature.effectSpecifiers?.throwsClause?.type,
        errorType.description == "ConfigurationFlattener.Error"
      else {
        throw MacroError(
          """
          @Aggregate method must be throwing and have error type ConfigurationFlattener.Error
          """
        )
      }

      guard
        method.parameters.map(\.callSiteLabel) == ["with"],
        method.parameters.map(\.type.description) == ["ConfigurationFlattener.Context"]
      else {
        throw MacroError(
          """
          @Aggregate method must have parameter list (with context: ConfigurationFlattener.Context)
          """
        )
      }

      return AggregateProperty(
        name: name,
        methodIdentifier: method.identifier,
        type: returnType
      )
    }
  }

  private static func lowerCamelCaseToSnakeCase(_ identifier: String) -> String {
    var out = ""
    var previousWasUppercase = false
    for character in identifier {
      if character.isUppercase {
        if !previousWasUppercase {
          out += "_"
        }
        out += character.lowercased()
        previousWasUppercase = true
      } else {
        out += String(character)
        previousWasUppercase = false
      }
    }
    return out
  }
}
