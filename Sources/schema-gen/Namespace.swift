import Foundation
import SwiftParser
import SwiftSyntax

enum NamespaceError: LocalizedError {
  case missingSourceFile(type: String)
  case missingDeclaration(type: String)
}

/// A namespace backed by a directory of Swift source code files.
struct Namespace {
  /// A directory of Swift source code files.
  var sourceDirectory: URL

  /// Searches the namespace for a type (`struct` or `enum`) with the specified identifier.
  ///
  /// Types are expected to be found in files of the same name (e.g. `PlistValue` should be in
  /// `PlistValue.swift`).
  /// - Parameter identifier: The type to look for.
  /// - Returns: A success if the type could be found, and a failure if it couldn't.
  func get(_ identifier: String) -> Result<TypeDecl, NamespaceError> {
    let file = sourceDirectory.appendingPathComponent("\(identifier).swift")

    guard let source = try? String(contentsOf: file) else {
      return .failure(.missingSourceFile(type: identifier))
    }

    let sourceFile = Parser.parse(source: source)

    for statement in sourceFile.statements {
      for child in statement.children(viewMode: .all) {
        guard let decl = child.asProtocol(DeclSyntaxProtocol.self) else {
          continue
        }

        if let structDecl = decl as? StructDeclSyntax {
          guard structDecl.name.text == identifier else {
            continue
          }
          return .success(.structDecl(structDecl))
        } else if let enumDecl = decl as? EnumDeclSyntax {
          guard enumDecl.name.text == identifier else {
            continue
          }
          return .success(.enumDecl(enumDecl))
        }
      }
    }

    return .failure(.missingDeclaration(type: identifier))
  }
}
