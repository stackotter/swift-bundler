//import Foundation
//import ArgumentParser
//
//struct RemoveFileHeaders: ParsableCommand {
//  @Option(name: [.customLong("directory"), .customShort("d")], help: "The directory of the package to run the postbuild script of", transform: URL.init(fileURLWithPath:))
//  var packageDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
//
//  func run() throws {
//    Bundler.removeFileHeaders(packageDir)
//  }
//}
//
//extension Bundler {
//  static func removeFileHeaders(_ packageDir: URL) {
//    let sourcesDir = packageDir.appendingPathComponent("Sources")
//    var contents: [URL] = []
//    do {
//      if let enumerator = FileManager.default.enumerator(at: sourcesDir, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
//        for case let fileURL as URL in enumerator {
//          let fileAttributes = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
//          if fileAttributes.isRegularFile! && fileURL.pathExtension == "swift" {
//            contents.append(fileURL)
//          }
//        }
//      }
//    } catch {
//      terminate("Failed to enumerate source files; \(error)")
//    }
//
//    for file in contents {
//      do {
//        var contents = try String(contentsOf: file)
//        if let match = contents.range(of: "//\n//  [^\n]*\n//  [^\n]*\n//\n//  Created by [^\n]*\n//\n?\n", options: .regularExpression) {
//          contents.replaceSubrange(match, with: "")
//          try contents.write(to: file, atomically: false, encoding: .utf8)
//        }
//      } catch {
//        terminate("Failed to remove file header from \(file.lastPathComponent); \(error)")
//      }
//    }
//  }
//}
