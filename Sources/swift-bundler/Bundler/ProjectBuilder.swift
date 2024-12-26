import Foundation
import SwiftBundlerBuilders
import Version

enum ProjectBuilder {
  static let builderProductName = "Builder"

  indirect enum Error: LocalizedError {
    case failedToCloneRepo(URL, ProcessError)
    case failedToWriteBuilderManifest(any Swift.Error)
    case failedToCreateBuilderSourceDirectory(URL, any Swift.Error)
    case failedToSymlinkBuilderSourceFile(any Swift.Error)
    case failedToBuildBuilder(name: String, SwiftPackageManagerError)
    case builderFailed(any Swift.Error)
    case missingProject(name: String, appName: String)
    case missingProduct(project: String, product: String, appName: String)
    case failedToBuildProject(name: String, Error)
    case failedToCopyProduct(source: URL, destination: URL, any Swift.Error)
    case other(any Swift.Error)

    var errorDescription: String? {
      switch self {
        case .failedToCloneRepo(let gitURL, let error):
          return """
            Failed to clone project source repository '\(gitURL)': \
            \(error.localizedDescription)
            """
        case .failedToCreateBuilderSourceDirectory(_, let error),
          .failedToWriteBuilderManifest(let error),
          .failedToSymlinkBuilderSourceFile(let error):
          return "Failed to generate builder package: \(error.localizedDescription)"
        case .failedToBuildBuilder(let name, _):
          return "Failed to build builder '\(name)'"
        case .builderFailed(let error):
          return "Failed to run builder: \(error.localizedDescription)"
        case .missingProject(let name, let appName):
          return "Missing project named '\(name)' (required by '\(appName)')"
        case .missingProduct(let project, let product, let appName):
          return "Missing product '\(project).\(product)' (required by '\(appName)')"
        case .failedToBuildProject(let name, let error):
          return "'\(name)': \(error.localizedDescription)"
        case .failedToCopyProduct(let source, _, let error):
          return """
            Failed to copy product '\(source.lastPathComponent)': \
            \(error.localizedDescription)
            """
        case .other(let error):
          return error.localizedDescription
      }
    }
  }

  struct BuiltProduct {
    var product: ProjectConfiguration.Product
    var location: URL
  }

  static func buildDependencies(
    _ dependencies: [AppConfiguration.Dependency],
    packageConfiguration: PackageConfiguration.Flat,
    packageDirectory: URL,
    scratchDirectory: URL,
    appProductsDirectory: URL,
    appName: String,
    platform: Platform,
    dryRun: Bool
  ) -> Result<[String: BuiltProduct], Error> {
    var builtProjects: Set<String> = []
    return dependencies.tryMap {
      dependency -> Result<(String, BuiltProduct), Error> in
      let projectName = dependency.project

      guard let project = packageConfiguration.projects[projectName] else {
        return .failure(Error.missingProject(name: projectName, appName: appName))
      }

      guard let product = project.products[dependency.product] else {
        return .failure(
          Error.missingProduct(
            project: projectName,
            product: dependency.product,
            appName: appName
          )
        )
      }

      let projectScratchDirectory = ScratchDirectoryStructure(
        scratchDirectory: scratchDirectory / projectName
      )

      let productsDirectoryExists = FileManager.default.itemExists(
        at: projectScratchDirectory.products,
        withType: .directory
      )

      let requiresBuilding = !builtProjects.contains(dependency.project)
      builtProjects.insert(dependency.project)

      let productPath = product.path(whenNamed: dependency.product, platform: platform)
      let builtProduct = projectScratchDirectory.build / productPath
      let productDestination = projectScratchDirectory.products / builtProduct.lastPathComponent

      let successValue = (
        dependency.identifier,
        BuiltProduct(
          product: product,
          location: productDestination
        )
      )

      guard !dryRun else {
        return .success(successValue)
      }

      return Result.success()
        .andThen(if: requiresBuilding) { _ in
          // Set up required directories and build whole project
          log.info("Building project '\(projectName)'")
          return Result.success()
            .andThenDoSideEffect(if: productsDirectoryExists) { _ in
              FileManager.default.removeItem(at: projectScratchDirectory.products)
                .mapError(Error.other)
            }.andThen { _ in
              projectScratchDirectory.createRequiredDirectories()
            }.andThen { _ in
              ProjectBuilder.buildProject(
                projectName,
                configuration: project,
                packageDirectory: packageDirectory,
                scratchDirectory: projectScratchDirectory
              ).mapError { error in
                Error.failedToBuildProject(name: projectName, error)
              }
            }
        }.andThenDoSideEffect { buildDirectory -> Result<Void, Error> in
          log.info("Copying product '\(dependency.identifier)'")
          return FileManager.default.copyItem(
            at: builtProduct,
            to: productDestination,
            onError: Error.failedToCopyProduct
          )
        }.replacingSuccessValue(with: successValue)
    }.map { pairs in
      Dictionary(pairs) { first, _ in first }
    }
  }

  struct ScratchDirectoryStructure {
    var root: URL
    var sources: URL
    var builder: URL
    var build: URL
    var products: URL
    var builderManifest: URL
    var builderSourceFile: URL

    var requireDirectories: [URL] {
      [
        root,
        builder,
        build,
        products,
        builderManifest.deletingLastPathComponent(),
        builderSourceFile.deletingLastPathComponent(),
      ]
    }

    init(scratchDirectory: URL) {
      root = scratchDirectory
      sources = scratchDirectory / "sources"
      builder = scratchDirectory / "builder"
      build = scratchDirectory / "build"
      products = scratchDirectory / "products"
      builderManifest = builder / "Package.swift"
      builderSourceFile = builder / "Sources/Builder/Builder.swift"
    }

    func createRequiredDirectories() -> Result<Void, Error> {
      requireDirectories.filter { directory in
        !FileManager.default.itemExists(at: directory, withType: .directory)
      }.tryForEach { directory in
        FileManager.default.createDirectory(at: directory).mapError(Error.other)
      }
    }
  }

  /// Builds a project and returns the directory containing the built
  /// products on success.
  static func buildProject(
    _ name: String,
    configuration: ProjectConfiguration.Flat,
    packageDirectory: URL,
    scratchDirectory: ScratchDirectoryStructure
  ) -> Result<Void, Error> {
    let gitURL: URL
    switch configuration.source {
      case .git(let url):
        gitURL = url
    }

    // Just sitting here to raise alarms when more types are added
    switch configuration.builder.type {
      case .wholeProject:
        break
    }

    let checkedOut = FileManager.default.itemExists(
      at: scratchDirectory.sources,
      withType: .directory
    )

    return Result.success()
      .andThen(if: !checkedOut) { _ in
        // Clone sources
        Process.create(
          "git",
          arguments: [
            "clone", "--recursive", gitURL.absoluteString, scratchDirectory.sources.path,
          ],
          runSilentlyWhenNotVerbose: false
        ).runAndWait().mapError { error in
          Error.failedToCloneRepo(gitURL, error)
        }
      }
      .andThen { _ in
        // Create builder source file symlink
        Result {
          let masterBuilderSourceFile = packageDirectory / configuration.builder.name
          if FileManager.default.fileExists(atPath: scratchDirectory.builderSourceFile.path) {
            try FileManager.default.removeItem(at: scratchDirectory.builderSourceFile)
          }
          try FileManager.default.createSymbolicLink(
            at: scratchDirectory.builderSourceFile,
            withDestinationURL: masterBuilderSourceFile
          )
        }.mapError(Error.failedToSymlinkBuilderSourceFile)
      }
      .andThen { _ in
        // Create/update the builder's Package.swift
        SwiftPackageManager.getToolsVersion(packageDirectory)
          .mapError(Error.other)
          .map { toolsVersion in
            generateBuilderPackageManifest(
              toolsVersion,
              builderAPI: configuration.builder.api
            )
          }
          .andThen { manifestContents in
            manifestContents.write(to: scratchDirectory.builderManifest)
              .mapError(Error.failedToWriteBuilderManifest)
          }
      }
      .andThen { _ in
        // Build the builder
        let buildContext = SwiftPackageManager.BuildContext(
          packageDirectory: scratchDirectory.builder,
          scratchDirectory: scratchDirectory.builder / ".build",
          configuration: .debug,
          architectures: [.current],
          platform: .host,
          additionalArguments: []
        )

        return SwiftPackageManager.build(
          product: builderProductName,
          buildContext: buildContext
        ).andThen { _ in
          SwiftPackageManager.getProductsDirectory(buildContext)
        }.mapError { error in
          Error.failedToBuildBuilder(name: configuration.builder.name, error)
        }
      }
      .andThen { productsDirectory in
        let inputPipe = Pipe()
        let process = Process()
        process.executableURL = productsDirectory / builderProductName
        process.standardInput = inputPipe
        process.currentDirectoryURL = scratchDirectory.sources

        let context = _BuilderContextImpl(
          buildDirectory: scratchDirectory.build
        )

        return Result { try process.run() }.andThen { _ in
          // Encode context
          JSONEncoder().encode(context)
        }.andThen { encodedContext in
          // Write context to stdin (as a single line)
          Result {
            inputPipe.fileHandleForWriting.write(encodedContext)
            inputPipe.fileHandleForWriting.write("\n")
          }
        }.andThen { _ in
          // Wait for builder to finish
          process.waitUntilExit()

          let status = Int(process.terminationStatus)
          if status == 0 {
            return .success()
          } else {
            let processError = ProcessError.nonZeroExitStatus(status)
            return .failure(Error.builderFailed(processError))
          }
        }.ifFailure { _ in
          process.terminate()
        }.mapError(Error.builderFailed)
      }
  }

  static func generateBuilderPackageManifest(
    _ swiftVersion: Version,
    builderAPI: ProjectConfiguration.Builder.Flat.API
  ) -> String {
    let dependency: String
    switch builderAPI {
      case .local(let path):
        dependency = """
                  .package(
                      name: "swift-bundler",
                      path: "\(path)"
                  )
          """
      case .git(let url, let requirement):
        let url = url ?? SwiftBundler.gitURL
        let revision: String
        switch requirement {
          case .revision(let value):
            revision = value
        }
        dependency = """
                  .package(
                      url: "\(url.absoluteString)",
                      revision: "\(revision)"
                  )
          """
    }

    return """
      // swift-tools-version:\(swiftVersion.major).\(swiftVersion.minor)
      import PackageDescription

      let package = Package(
          name: "Builder",
          platforms: [.macOS(.v10_15)],
          products: [
              .executable(name: "Builder", targets: ["Builder"])
          ],
          dependencies: [
      \(dependency)
          ],
          targets: [
              .executableTarget(
                  name: "\(builderProductName)",
                  dependencies: [
                      .product(name: "SwiftBundlerBuilders", package: "swift-bundler")
                  ]
              )
          ]
      )
      """
  }
}
