struct AppConfiguration {
  var target: String
  var version: String
  var category: String
  var bundleIdentifier: String
  var minMacOSVersion: String
  var extraPlistEntries: [String: String]
  
  static var `default` = AppConfiguration(
    target: "ExampleApp",
    version: "0.1.0",
    category: "public.app-category.example",
    bundleIdentifier: "com.example.example",
    minMacOSVersion: "10.13",
    extraPlistEntries: [:])
}
