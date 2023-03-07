import SwiftSyntax

/// A type declaration (either a `struct` or an `enum`).
enum TypeDecl {
  case structDecl(StructDeclSyntax)
  case enumDecl(EnumDeclSyntax)

  /// The type's children.
  var children: SyntaxChildren {
    switch self {
      case .structDecl(let decl):
        return decl.children(viewMode: .all)
      case .enumDecl(let decl):
        return decl.children(viewMode: .all)
    }
  }

  /// The type's identifier.
  var identifier: String {
    switch self {
      case .structDecl(let decl):
        return decl.identifier.text
      case .enumDecl(let decl):
        return decl.identifier.text
    }
  }

  /// The type's properties.
  var properties: [PropertyDecl] {
    var properties: [PropertyDecl] = []
    for child in children {
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
}
