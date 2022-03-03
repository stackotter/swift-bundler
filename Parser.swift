import Parsing // pointfreeco/swift-parsing ~> 0.7.1

let parser = Parse {
    Prefix { $0 != "{" }
    Optionally {
        "{"
        Prefix { $0 != "}" }
        "}"
    }
}

let variables: [String: String] = [
    "COMMIT_HASH": "abcd1234"
]

var output = ""
var input = "This is the commit hash: {COMMIT_HASH}, have fun!"[...]
while true {
    let (string, variable) = try! parser.parse(&input)
    output += string

    guard let variable = variable else {
        break
    }

    output += variables[String(variable)] ?? "INVALID_VARIABLE"
}

print(output)