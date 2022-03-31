import Foundation

/// A utility for creating Xcode related support files (i.e. Xcode schemes).
enum XcodeSupportGenerator {
  /// Generates the schemes required for Xcode to build and run a package.
  /// - Parameters:
  ///   - configuration: The package's configuration.
  ///   - packageDirectory: The package's root directory.
  /// - Returns: If an error occurs, a failure is returned.
  static func generateXcodeSupport(
    for configuration: Configuration,
    in packageDirectory: URL
  ) -> Result<Void, XcodeSupportGeneratorError> {
    return getSchemesDirectory(in: packageDirectory)
      .flatMap { schemesDirectory in
        for (app, appConfiguration) in configuration.apps {
          let result = generateAppScheme(for: app, with: appConfiguration, in: schemesDirectory)
          if case .failure = result {
            return result
          }
        }

        return .success()
      }
  }

  /// Gets the location to create Xcode schemes for a given package.
  /// - Parameter packageDirectory: The root directory of the package.
  /// - Returns: The package's schemes directory. If an error occurs, a failure is returned.
  private static func getSchemesDirectory(in packageDirectory: URL) -> Result<URL, XcodeSupportGeneratorError> {
    let schemesDirectory = packageDirectory.appendingPathComponent(".swiftpm/xcode/xcshareddata/xcschemes")
    do {
      try FileManager.default.createDirectory(at: schemesDirectory)
    } catch {
      return .failure(.failedToCreateSchemesDirectory(schemesDirectory, error))
    }

    return .success(schemesDirectory)
  }

  /// Generates the Xcode schemes for an app.
  /// - Parameters:
  ///   - app: The name of the app.
  ///   - configuration: The app's configuration.
  ///   - schemesDirectory: The directory to output the schemes to.
  /// - Returns: If an error occurs, a failure is returned.
  private static func generateAppScheme(
    for app: String,
    with configuration: AppConfiguration,
    in schemesDirectory: URL
  ) -> Result<Void, XcodeSupportGeneratorError> {
    return generateAppSchemeContents(for: app, with: configuration)
      .flatMap { contents in
        do {
          try contents.write(
            to: schemesDirectory.appendingPathComponent("\(app).xcscheme"),
            atomically: false,
            encoding: .utf8)
          return .success()
        } catch {
          return .failure(.failedToWriteToAppScheme(app: app, error))
        }
      }
  }

  // swiftlint:disable function_body_length
  /// Generates the contents of the Xcode scheme for an app.
  /// - Parameters:
  ///   - app: The name of the app.
  ///   - configuration: The app's configuration.
  /// - Returns: The contents of the scheme. If an error occurs, a failure is returned.
  private static func generateAppSchemeContents(
    for app: String,
    with configuration: AppConfiguration
  ) -> Result<String, XcodeSupportGeneratorError> {
    log.info("Generating scheme for '\(app).app'")

    let product = configuration.product

    // Get the global output directory
    let outputDirectory: URL
    switch Bundler.getApplicationSupportDirectory() {
      case let .success(applicationSupport):
        // This shouldn't be able to happen, but it would break stuff if it did
        guard !applicationSupport.path.contains("'") else {
          return .failure(.applicationSupportDirectoryCannotContainSingleQuote(applicationSupport))
        }

        outputDirectory = applicationSupport.appendingPathComponent("build")
      case let .failure(error):
        return .failure(.failedToGetApplicationSupportDirectory(error))
    }

    // Get the output app bundle location
    let outputAppBundle = outputDirectory.appendingPathComponent("\(product).app")
    do {
      try FileManager.default.createDirectory(at: outputAppBundle)
    } catch {
      return .failure(.failedToCreateOutputBundle(error))
    }

    // The escaped strings required to fill in the template
    let escapedOutputPath = outputDirectory.path
      .replacingOccurrences(of: "\"", with: "\\\"")
    let escapedOutputBundlePath = outputAppBundle.path
      .replacingOccurrences(of: "\"", with: "")
    let packagePath = "${WORKSPACE_PATH}/../../../"

    // Commands to put in the scheme
    let command = "/opt/swift-bundler/swift-bundler bundle"
    let arguments = "\(app) -d \(packagePath) --products-directory ${BUILT_PRODUCTS_DIR} -o '\(escapedOutputPath)' --skip-build --built-with-xcode"
    let createBundle = "\(command) \(arguments)"

    // Create the scheme's contents from a massive template
    return .success("""
<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1300"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <PostActions>
         <ExecutionAction
            ActionType = "Xcode.IDEStandardExecutionActionsCore.ExecutionActionType.ShellScriptAction">
            <ActionContent
               title = "Bundle executable"
               scriptText = "\(createBundle)">
               <EnvironmentBuildable>
                  <BuildableReference
                     BuildableIdentifier = "primary"
                     BlueprintIdentifier = "\(product)"
                     BuildableName = "\(product)"
                     BlueprintName = "\(product)"
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
               BlueprintIdentifier = "\(product)"
               BuildableName = "\(product)"
               BlueprintName = "\(product)"
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
         FilePath = "\(escapedOutputBundlePath)">
      </PathRunnable>
      <MacroExpansion>
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "\(product)"
            BuildableName = "\(product)"
            BlueprintName = "\(product)"
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
            BlueprintIdentifier = "\(product)"
            BuildableName = "\(product)"
            BlueprintName = "\(product)"
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
""")
  }
  // swiftlint:enable function_body_length
}
