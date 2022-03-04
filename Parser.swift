import Parsing // pointfreeco/swift-parsing ~> 0.7.1



let variables: [String: String] = [
    "COMMIT_HASH": "abcd1234"
]

var output = ""
var input = "This is the commit hash: {COMMIT_HASH}, have fun!"[...]

print(output)