import Foundation
import ArgumentParser

struct GenerateXcodeSupport: ParsableCommand {
  @Option(name: [.customLong("directory"), .customShort("d")], help: "The directory containing the package to generate xcode support files for", transform: URL.init(fileURLWithPath:))
  var packageDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

  func run() throws {
    Bundler.generateXcodeSupport(packageDir)
    log.info("Done")
  }
}

extension Bundler {
  static func generateXcodeSupport(_ packageDir: URL) {
    // We used to create an xcodeproj but that had issues with autocomplete and certain types of dependencies showing up in multiple places, so now we just prepopulate the .swiftpm directory which xcode reads from when opening a swift package
    // And now `swift package generate-xcodeproj` is getting phased out too. This solution just works much nicer in general
    log.info("Creating schemes")
    let packageName = getPackageName(from: packageDir)
    let schemeString = createScheme(for: packageName)
    let schemesDir = packageDir.appendingPathComponent(".swiftpm/xcode/xcshareddata/xcschemes")
    let schemeFile = schemesDir.appendingPathComponent("\(packageName).xcscheme")
    do {
      try FileManager.default.createDirectory(at: schemesDir)
      try schemeString.write(to: schemeFile, atomically: false, encoding: .utf8)
    } catch {
      terminate("Failed to create scheme at \(schemeFile.path); \(error)")
    }
  }

  fileprivate static func createScheme(for packageName: String) -> String {
    let runPrebuild = "swift bundler prebuild -d ${PROJECT_DIR}"
    let createBundle = "swift bundler bundle -d ${WORKSPACE_PATH}/../../../ --products-dir ${BUILT_PRODUCTS_DIR} -o /private/tmp/swift-bundler/ --dont-fix-bundles"
    let runPostbuild = "swift bundler postbuild -d ${PROJECT_DIR}"
    return """
<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1300"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <PreActions>
         <ExecutionAction
            ActionType = "Xcode.IDEStandardExecutionActionsCore.ExecutionActionType.ShellScriptAction">
            <ActionContent
               title = "Run Prebuild Script"
               scriptText = "\(runPrebuild)">
               <EnvironmentBuildable>
                  <BuildableReference
                     BuildableIdentifier = "primary"
                     BlueprintIdentifier = "\(packageName)"
                     BuildableName = "\(packageName)"
                     BlueprintName = "\(packageName)"
                     ReferencedContainer = "container:">
                  </BuildableReference>
               </EnvironmentBuildable>
            </ActionContent>
         </ExecutionAction>
      </PreActions>
      <PostActions>
         <ExecutionAction
            ActionType = "Xcode.IDEStandardExecutionActionsCore.ExecutionActionType.ShellScriptAction">
            <ActionContent
               title = "Bundle executable"
               scriptText = "\(createBundle)">
               <EnvironmentBuildable>
                  <BuildableReference
                     BuildableIdentifier = "primary"
                     BlueprintIdentifier = "\(packageName)"
                     BuildableName = "\(packageName)"
                     BlueprintName = "\(packageName)"
                     ReferencedContainer = "container:">
                  </BuildableReference>
               </EnvironmentBuildable>
            </ActionContent>
         </ExecutionAction>
         <ExecutionAction
            ActionType = "Xcode.IDEStandardExecutionActionsCore.ExecutionActionType.ShellScriptAction">
            <ActionContent
               title = "Run Postbuild Script"
               scriptText = "\(runPostbuild)">
               <EnvironmentBuildable>
                  <BuildableReference
                     BuildableIdentifier = "primary"
                     BlueprintIdentifier = "\(packageName)"
                     BuildableName = "\(packageName)"
                     BlueprintName = "\(packageName)"
                     ReferencedContainer = "container:">
                  </BuildableReference>
               </EnvironmentBuildable>
            </ActionContent>
         </ExecutionAction>
      </PostActions>
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "NO"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "\(packageName)"
               BuildableName = "\(packageName)"
               BlueprintName = "\(packageName)"
               ReferencedContainer = "container:">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <PathRunnable
         runnableDebuggingMode = "0"
         FilePath = "/private/tmp/swift-bundler/\(packageName).app">
      </PathRunnable>
      <MacroExpansion>
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "\(packageName)"
            BuildableName = "\(packageName)"
            BlueprintName = "\(packageName)"
            ReferencedContainer = "container:">
         </BuildableReference>
      </MacroExpansion>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "\(packageName)"
            BuildableName = "\(packageName)"
            BlueprintName = "\(packageName)"
            ReferencedContainer = "container:">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""
  }
}