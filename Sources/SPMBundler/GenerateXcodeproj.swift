import Foundation
import ArgumentParser

struct GenerateXcodeproj: ParsableCommand {
  @Option(name: [.customLong("directory"), .customShort("d")], help: "The directory containing the package to create a .xcodeproj for", transform: URL.init(fileURLWithPath:))
  var packageDir: URL

  mutating func run() throws {
    // Load configuration
    log.info("Loading configuration")
    let data = try! Data(contentsOf: packageDir.appendingPathComponent("Bundle.json"))
    let config = try! JSONDecoder().decode(Configuration.self, from: data)

    // Generate the default xcodeproj
    log.info("Generating default xcodeproj")
    let packageName = getPackageName(from: packageDir)
    shell("rm -rf \(packageName).xcodeproj; swift package generate-xcodeproj", packageDir)

    let xcodeprojDir = packageDir.appendingPathComponent("\(packageName).xcodeproj")
    let pbxproj = xcodeprojDir.appendingPathComponent("project.pbxproj")
    var contents = try! String(contentsOf: pbxproj)

    // Rename existing target
    contents = contents.replacingOccurrences(of: "BundlerHelloWorld::BundlerHelloWorld", with: "BundlerHelloWorld::BundlerHelloWorldDummy")
    contents = contents.replacingOccurrences(of: """
         dependencies = (
         );
         name = "\(packageName)";
""", with: """
         dependencies = (
         );
         name = "\(packageName) (~dummy)";
""")
    contents = contents.replacingOccurrences(of: "productName = \"\(packageName)\"", with: "productName = \"\(packageName) (~dummy)\"")
    contents = contents.replacingOccurrences(of: "path = \"\(packageName)\"", with: "path = \"\(packageName) (~dummy)\"")

    // Insert bundle identifier
    contents = contents.replacingOccurrences(of: """
         buildSettings = {
""", with: """
         buildSettings = {
            PRODUCT_BUNDLE_IDENTIFIER = "\(config.bundleIdentifier)";
""")

    var lines = contents.split(separator: "\n")
    let objectsStartIndex = lines.firstIndex(of: "   objects = {")! + 1

    // Insert the new target and build phases
    log.info("Inserting new targets and build phases")
    let shellScript = """
cd ~/Desktop/Projects/DeltaClient/SPMBundler
swift run SPMBundler build -d \(packageDir.path) -o ${BUILT_PRODUCTS_DIR} -c release
"""
    let escapedShellScript = shellScript.replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: "\"", with: "\\\"")

    lines.insert("""
      "\(packageName)::\(packageName)" = {
         isa = "PBXNativeTarget";
         buildConfigurationList = "OBJ_16";
         buildPhases = (
            "BuildPhase::ShellScript"
         );
         dependencies = (
         );
         name = "\(packageName) (macOS)";
         productName = "\(packageName)";
         productReference = "\(packageName)::\(packageName)::Product";
         productType = "com.apple.product-type.application";
      };
      "\(packageName)::\(packageName)::Product" = {
         isa = "PBXFileReference";
         path = "\(packageName).app";
         explicitFileType = wrapper.application;
         sourceTree = "BUILT_PRODUCTS_DIR";
      };
      "BuildPhase::ShellScript" = {
         isa = PBXShellScriptBuildPhase;
         alwaysOutOfDate = 1;
         buildActionMask = 2147483647;
         files = (
         );
         inputFileListPaths = (
         );
         inputPaths = (
         );
         outputFileListPaths = (
         );
         outputPaths = (
         );
         runOnlyForDeploymentPostprocessing = 0;
         shellPath = /bin/sh;
         shellScript = "\(escapedShellScript)";
      };
""", at: objectsStartIndex)
    
    // Insert new target
    let targetsStartIndex = lines.firstIndex(of: "         targets = (")! + 1
    lines.insert("            \"\(packageName)::\(packageName)\",", at: targetsStartIndex)

    // Write the changes
    try! lines.joined(separator: "\n").write(to: pbxproj, atomically: false, encoding: .utf8)

    // Edit the schemes
    log.info("Editing schemes")
    let schemesDir = xcodeprojDir.appendingPathComponent("xcshareddata/xcschemes")
    let originalScheme = schemesDir.appendingPathComponent("\(packageName).xcscheme")
    let schemeContents = try! String(contentsOf: originalScheme)

    // Edit and rename the original scheme
    var editedSchemeContents = schemeContents.replacingOccurrences(of: "BlueprintName = \"\(packageName)\"", with: "BlueprintName = \"\(packageName) (~dummy)\"")
    editedSchemeContents = editedSchemeContents.replacingOccurrences(of: "'$(TARGET_NAME)'", with: "\(packageName)Dummy")
    try! editedSchemeContents.write(to: schemesDir.appendingPathComponent("\(packageName) (~dummy).xcscheme"), atomically: false, encoding: .utf8)
    try! FileManager.default.removeItem(at: originalScheme)

    // Create the new scheme and write it to the file
    var newSchemeContents = schemeContents.replacingOccurrences(of: "BlueprintName = \"\(packageName)\"", with: "BlueprintName = \"\(packageName) (macOS)\"")
    newSchemeContents = newSchemeContents.replacingOccurrences(of: "'$(TARGET_NAME)'", with: "\(packageName).app")
    let newScheme = schemesDir.appendingPathComponent("\(packageName) (macOS).xcscheme")
    try! newSchemeContents.write(to: newScheme, atomically: false, encoding: .utf8)

    // Create Info.plist
    log.info("Creating Info.plist")
    let infoPlist = createAppInfoPlist(
      packageName: packageName, 
      bundleIdentifier: config.bundleIdentifier, 
      versionString: config.versionString, 
      buildNumber: config.buildNumber, 
      category: config.category, 
      minOSVersion: config.minOSVersion)
    let infoPlistFile = xcodeprojDir.appendingPathComponent("\(packageName)_Info.plist")
    try! infoPlist.write(to: infoPlistFile, atomically: false, encoding: .utf8)
  }
}