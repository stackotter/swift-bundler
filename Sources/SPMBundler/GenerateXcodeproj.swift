import Foundation
import ArgumentParser

struct GenerateXcodeproj: ParsableCommand {
  @Option(name: [.customLong("directory"), .customShort("d")], help: "The directory containing the package to create a .xcodeproj for", transform: URL.init(fileURLWithPath:))
  var packageDir: URL

  func run() throws {
    // Load configuration
    log.info("Loading configuration")
    let config: Configuration
    do {
      let data = try Data(contentsOf: packageDir.appendingPathComponent("Bundle.json"))
      config = try JSONDecoder().decode(Configuration.self, from: data)
    } catch {
      log.error("Failed to load Bundle.json; \(error)")
      Foundation.exit(1)
    }

    // Generate the default xcodeproj
    log.info("Generating default xcodeproj")
    let packageName = getPackageName(from: packageDir)
    let xcodeprojDir = packageDir.appendingPathComponent("\(packageName).xcodeproj")
    do {
      if FileManager.default.itemExists(at: xcodeprojDir, withType: .directory) {
        try FileManager.default.removeItem(at: xcodeprojDir)
      }
    } catch {
      log.error("Failed to remove existing xcodeproj; \(error)")
      Foundation.exit(1)
    }

    if Shell.getExitStatus("swift package generate-xcodeproj", packageDir) != 0 {
      log.error("Failed to generate default swiftpm xcodeproj")
      Foundation.exit(1)
    }

    let pbxproj = xcodeprojDir.appendingPathComponent("project.pbxproj")
    var contents: String
    do {
      contents = try String(contentsOf: pbxproj)
    } catch {
      log.error("Failed to read contents of project.pbxproj; \(error)")
      Foundation.exit(1)
    }

    // Get build configuration list object id
    var lines = contents.split(separator: "\n")
    let buildConfigurationListId = lines[lines.firstIndex(of: "      \"\(packageName)::\(packageName)\" = {")! + 2].split(separator: "\"")[1]

    // Rename existing target
    contents = contents.replacingOccurrences(of: "\(packageName)::\(packageName)", with: "\(packageName)::\(packageName)Dummy")
    contents = contents.replacingOccurrences(of: """
         dependencies = (
         );
         name = "\(packageName)";
""", with: """
         dependencies = (
         );
         name = "\(packageName) (dummy)";
""")
    contents = contents.replacingOccurrences(of: "productName = \"\(packageName)\"", with: "productName = \"\(packageName) (dummy)\"")
    contents = contents.replacingOccurrences(of: "path = \"\(packageName)\"", with: "path = \"\(packageName) (dummy)\"")

    // Insert bundle identifier
    contents = contents.replacingOccurrences(of: """
         buildSettings = {
""", with: """
         buildSettings = {
            PRODUCT_BUNDLE_IDENTIFIER = "\(config.bundleIdentifier)";
""")

    // Insert the new target and build phases
    log.info("Inserting new targets and build phases")
    lines = contents.split(separator: "\n")
    guard let objectsIndex = lines.firstIndex(of: "   objects = {") else {
      log.error("Failed to get line number of objects declaration in project.pbxproj")
      Foundation.exit(1)
    }
    let objectsStartIndex = objectsIndex + 1

    let shellScript = """
cd ~/Desktop/Projects/DeltaClient/SPMBundler
swift run SPMBundler build -d \(packageDir.path) -o ${BUILT_PRODUCTS_DIR} -c ${CONFIGURATION}
"""
    let escapedShellScript = shellScript.replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: "\"", with: "\\\"")

    lines.insert("""
      "\(packageName)::\(packageName)" = {
         isa = "PBXNativeTarget";
         buildConfigurationList = "\(buildConfigurationListId)";
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
    guard let targetsIndex = lines.firstIndex(of: "         targets = (") else {
      log.error("Failed to get index of targets declaration in project.pbxproj")
      Foundation.exit(1)
    }
    let targetsStartIndex = targetsIndex + 1
    lines.insert("            \"\(packageName)::\(packageName)\",", at: targetsStartIndex)

    // Write the changes
    do {
      try lines.joined(separator: "\n").write(to: pbxproj, atomically: false, encoding: .utf8)
    } catch {
      log.error("Failed to write to project.pbxproj; \(error)")
      Foundation.exit(1)
    }

    // Edit the schemes
    log.info("Editing schemes")
    let schemesDir = xcodeprojDir.appendingPathComponent("xcshareddata/xcschemes")
    let originalScheme = schemesDir.appendingPathComponent("\(packageName).xcscheme")
    let packageScheme = schemesDir.appendingPathComponent("\(packageName)-Package.xcscheme")
    let schemeContents: String
    do {
      schemeContents = try String(contentsOf: originalScheme)
    } catch {
      log.error("Failed to read \(packageName).xcscheme; \(error)")
      Foundation.exit(1)
    }

    // Remove the default schemes
    do {
      try FileManager.default.removeItem(at: originalScheme)
      try FileManager.default.removeItem(at: packageScheme)
    } catch {
      log.error("Failed to remove default schemes; \(error)")
      Foundation.exit(1)
    }

    // Create the new scheme and write it to the file
    var newSchemeContents = schemeContents.replacingOccurrences(of: "BlueprintName = \"\(packageName)\"", with: "BlueprintName = \"\(packageName) (macOS)\"")
    newSchemeContents = newSchemeContents.replacingOccurrences(of: "'$(TARGET_NAME)'", with: "\(packageName).app")
    newSchemeContents = newSchemeContents.replacingOccurrences(of: """
      </BuildActionEntry>
""", with: """
      </BuildActionEntry>
      <BuildActionEntry buildForTesting = "NO" buildForRunning = "NO" buildForProfiling = "NO" buildForArchiving = "NO" buildForAnalyzing = "NO">
        <BuildableReference
          BuildableIdentifier = "primary"
          BlueprintIdentifier = "\(packageName)::\(packageName)Dummy"
          BuildableName = "\(packageName)"
          BlueprintName = "\(packageName) (dummy)"
          ReferencedContainer = "container:\(packageName).xcodeproj">
        </BuildableReference>
      </BuildActionEntry>
""")
    let newScheme = schemesDir.appendingPathComponent("\(packageName) (macOS).xcscheme")
    do {
      try newSchemeContents.write(to: newScheme, atomically: false, encoding: .utf8)
    } catch {
      log.error("Failed to create new scheme; \(error)")
      Foundation.exit(1)
    }

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
    do {
      try infoPlist.write(to: infoPlistFile, atomically: false, encoding: .utf8)
    } catch {
      log.error("Failed to create Info.plist; \(error)")
      Foundation.exit(1)
    }
  }
}