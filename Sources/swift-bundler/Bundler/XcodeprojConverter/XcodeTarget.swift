import Foundation

extension XcodeprojConverter {
  struct XcodeTarget {
    var name: String
    var identifier: String?
    var version: String?
    var sources: [XcodeFile]
    var resources: [XcodeFile]

    var files: [XcodeFile] {
      return sources + resources
    }
  }
}
