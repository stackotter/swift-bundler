struct CommandLine: CustomStringConvertible, Equatable {
  var command: String
  var arguments: [String]

  /// > Warning: Do not rely on this to correctly escape arguments, intended for displaying commands
  /// > to the user, not for turning commands into safe strings to pass to bash.
  var description: String {
    ([command] + arguments).map { argument in
      argument
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: " ", with: "\\ ")
        .replacingOccurrences(of: "'", with: "\\ ")
        .replacingOccurrences(of: "\"", with: "\\\"")
    }.joined(separator: " ")
  }

  /// > Warning: This is not robust, it is only designed to work on well-formed command lines
  /// > without any bash interpolations or the likes
  static func lenientParse(_ commandLine: String) -> CommandLine {
    var arguments: [String] = []
    var currentArgument: String = ""
    var openingQuote: Character?
    var nextCharacterIsEscaped = false
    for character in commandLine {
      if nextCharacterIsEscaped {
        currentArgument.append(character)
        nextCharacterIsEscaped = false
      } else if character == openingQuote {
        openingQuote = nil
        arguments.append(currentArgument)
        currentArgument = ""
      } else if character == "\\" {
        if openingQuote == "'" {
          currentArgument.append("\\")
        }
        nextCharacterIsEscaped = true
      } else if character == " ", openingQuote == nil {
        if !currentArgument.isEmpty {
          arguments.append(currentArgument)
          currentArgument = ""
        }
      } else if character == "\"" || character == "\'" {
        openingQuote = character
      } else {
        currentArgument.append(character)
      }
    }

    if !currentArgument.isEmpty {
      arguments.append(currentArgument)
    }

    let command = arguments[0]
    return CommandLine(
      command: command,
      arguments: Array(arguments.dropFirst())
    )
  }
}
