import Foundation

extension XcodeprojConverter {
  struct XcodeTarget {
    var name: String
    var sources: [XcodeFile]
    var resources: [XcodeFile]

    var files: [XcodeFile] {
      return sources + resources
    }
  }
}
